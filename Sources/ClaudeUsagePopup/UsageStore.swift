import AppKit
import SwiftUI

struct Bubble: Equatable {
    let id = UUID()
    let text: String
}

/// Polls usage, figures out the mascot's mood, and fires the one-shot animations
/// (speech bubbles, shakes, confetti) when something interesting happens.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var error: UsageError?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var bubble: Bubble?
    /// Bumped to trigger an animation; views watch these with `onChange`/`animation(value:)`.
    @Published private(set) var confettiCount = 0
    @Published private(set) var shakeCount = 0
    @Published private(set) var partyUntil: Date?

    /// Called when we have something worth a system notification.
    var notify: (_ title: String, _ body: String) -> Void = { _, _ in }

    private let demo: Bool
    private var pollTask: Task<Void, Never>?
    private var bubbleTask: Task<Void, Never>?
    private var ticker: Timer?
    private var nextDelay = Config.pollInterval
    private var rateLimitStrikes = 0
    private var lastAttempt = Date.distantPast
    private var alertLevel: Int?
    private var celebratedResets: Set<Date> = []

    private static let cacheKey = "lastSnapshot"

    init(demo: Bool = false) {
        self.demo = demo
        if !demo { loadCache() }
    }

    var mood: Mood {
        if let partyUntil, partyUntil > Date() { return .party }
        guard let worst = snapshot?.worst else { return error == nil ? .chill : .confused }
        return Mood.forPercent(worst.percent)
    }

    func start() {
        if demo { startDemo() } else { startPolling() }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
    }

    func refreshNow() {
        // While Anthropic has us on a timeout, let the backoff finish instead of piling on.
        guard !demo, rateLimitStrikes == 0 else { return }
        pollTask?.cancel()
        startPolling()
    }

    /// Clicking the mascot: say hi, report status, and refresh.
    func poke() {
        withAnimation(.easeOut(duration: 0.5)) { shakeCount += 1 }
        say(statusLine())
        if Date().timeIntervalSince(lastAttempt) > Config.manualRefreshCooldown { refreshNow() }
    }

    // MARK: Polling

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(self.nextDelay * 1_000_000_000))
            }
        }
    }

    private func refresh() async {
        lastAttempt = Date()
        do {
            let fresh = try await UsageAPI.fetch()
            error = nil
            rateLimitStrikes = 0
            nextDelay = Config.pollInterval
            apply(fresh)
            saveCache()
        } catch {
            let usageError = error as? UsageError ?? .network(error.localizedDescription)
            if case .rateLimited(let retryAfter) = usageError {
                // Back off 2, 4, 8… minutes (up to 15). Retry-After is often 0, so it only ever lengthens the wait.
                rateLimitStrikes += 1
                let backoff = min(15 * 60, 120 * pow(2, Double(rateLimitStrikes - 1)))
                nextDelay = max(retryAfter ?? 0, backoff)
            } else {
                nextDelay = Config.pollInterval
            }
            self.error = usageError
        }
    }

    // MARK: Cache (so a restart shows your last numbers instead of an empty card)

    private func saveCache() {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              var cached = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else { return }
        // Windows that already reset while we were closed start fresh (and don't throw confetti).
        for window in [\UsageSnapshot.session, \UsageSnapshot.weekly] {
            if let resetsAt = cached[keyPath: window]?.resetsAt, resetsAt <= Date() {
                cached[keyPath: window]?.percent = 0
                cached[keyPath: window]?.resetsAt = nil
            }
        }
        snapshot = cached
    }

    /// Runs every time new numbers arrive, from the API or the demo.
    private func apply(_ fresh: UsageSnapshot) {
        let old = snapshot
        snapshot = fresh
        lastUpdated = Date()

        // A window whose reset time jumped forward means a new block began while we weren't looking.
        if let before = old?.session, let was = before.resetsAt, let now = fresh.session?.resetsAt,
           now.timeIntervalSince(was) > 30 * 60 {
            celebrateReset(of: before, key: was)
        }
        if let before = old?.weekly, let was = before.resetsAt, let now = fresh.weekly?.resetsAt,
           now.timeIntervalSince(was) > 24 * 3600 {
            celebrateReset(of: before, key: was)
        }

        guard let worst = fresh.worst else { return }
        let level = Self.alertLevel(for: worst.percent)
        if level > (alertLevel ?? 0) { announce(level: level, meter: worst) }
        alertLevel = level
    }

    /// Notices a reset the moment the countdown hits zero, without waiting for the next poll.
    private func tick() {
        let now = Date()
        for window in [\UsageSnapshot.session, \UsageSnapshot.weekly] {
            guard var meter = snapshot?[keyPath: window], let resetsAt = meter.resetsAt, resetsAt <= now else { continue }
            let isNew = !celebratedResets.contains(resetsAt)
            celebrateReset(of: meter, key: resetsAt)
            meter.percent = 0
            meter.resetsAt = nil
            snapshot?[keyPath: window] = meter
            if isNew { scheduleRefresh(after: 10) }
        }
        if let partyUntil, partyUntil <= now { self.partyUntil = nil }
    }

    private func scheduleRefresh(after seconds: TimeInterval) {
        guard !demo else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self?.refreshNow()
        }
    }

    // MARK: Moments

    private static func alertLevel(for percent: Double) -> Int {
        switch percent {
        case 100...: return 3
        case Config.panicAt...: return 2
        case Config.nervousAt...: return 1
        default: return 0
        }
    }

    private func announce(level: Int, meter: Meter) {
        let pct = Format.percent(meter.percent)
        let which = meter.id == "session" ? "5h session" : "weekly limit"
        let text: String
        switch level {
        case 1: text = "psst… \(pct) of your \(which) used 👀"
        case 2: text = "\(pct) used — pace yourself! 🥵"
        default:
            let back = meter.resetsAt.map { " · back in \(Format.countdown(to: $0))" } ?? ""
            text = "out of tokens, nap time 😴\(back)"
        }
        withAnimation(.linear(duration: 0.6)) { shakeCount += 1 }
        say(text)
        notify("Claude usage: \(pct) of your \(which)", text)
    }

    private func celebrateReset(of meter: Meter, key: Date) {
        guard celebratedResets.insert(key).inserted else { return }
        let text: String
        if meter.id == "session" {
            text = meter.percent >= Config.panicAt ? "we're back!! fresh 5h block 🎉" : "new 5-hour block! ✨"
        } else {
            text = "new week, new tokens 🌈"
        }
        confettiCount += 1
        partyUntil = Date().addingTimeInterval(6)
        say(text)
        if meter.percent >= Config.nervousAt { notify("Claude usage reset", text) }
    }

    private func statusLine() -> String {
        guard let snapshot, let session = snapshot.session else {
            return error == nil ? "hi! still checking… 👋" : "hmm, can't see your usage 🤔"
        }
        let countdown = session.resetsAt.map { Format.countdown(to: $0) }
        let reset = countdown.map { " · resets in \($0)" } ?? ""
        switch mood {
        case .sleeping: return "zzz… back in \(countdown ?? "a bit") 💤"
        case .panic, .nervous: return "\(Format.percent(session.percent)) used\(reset) 😬"
        default: return "boop! \(Format.percent(session.percent)) used\(reset) 🌿"
        }
    }

    func say(_ text: String) {
        bubbleTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { bubble = Bubble(text: text) }
        bubbleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Config.bubbleDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.bubble = nil }
        }
    }

    // MARK: Demo mode (`--demo`): burns through a fake session every ~20 seconds.

    private func startDemo() {
        var percent = 8.0
        var cycle = 0.0
        var holdTicks = 0
        let start = Date()
        func snapshot() -> UsageSnapshot {
            UsageSnapshot(
                session: Meter(id: "session", label: "5h session", percent: percent,
                               resetsAt: start.addingTimeInterval((cycle + 1) * 5 * 3600)),
                weekly: Meter(id: "weekly", label: "Week", percent: min(99, 21 + cycle * 9 + percent * 0.12),
                              resetsAt: start.addingTimeInterval(3 * 86400 + 7 * 3600)),
                extras: [Meter(id: "scoped-0", label: "Opus · week", percent: min(99, 12 + percent * 0.3), resetsAt: nil)]
            )
        }
        apply(snapshot())
        Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if percent >= 100 {
                    holdTicks += 1
                    if holdTicks < 6 { return }
                    holdTicks = 0
                    percent = 3
                    cycle += 1
                } else {
                    percent = min(100, percent + 7)
                }
                self.apply(snapshot())
            }
        }
    }

    // MARK: Previews / asset rendering

    func setPreview(_ snapshot: UsageSnapshot?, error: UsageError? = nil, bubble: String? = nil, party: Bool = false) {
        self.snapshot = snapshot
        self.error = error
        self.bubble = bubble.map { Bubble(text: $0) }
        self.partyUntil = party ? Date().addingTimeInterval(3600) : nil
    }
}
