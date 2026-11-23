import SwiftUI

/// Knobs you might want to tweak. Rebuild with `./install.sh` after changing them.
enum Config {
    /// How often to ask Anthropic for fresh numbers (seconds). The endpoint is rate limited,
    /// so going much lower tends to get you "slow down" errors.
    static let pollInterval: TimeInterval = 120

    /// Clicking Tok refreshes at most this often (seconds).
    static let manualRefreshCooldown: TimeInterval = 30

    /// Usage percentages where the mascot starts to worry.
    static let busyAt: Double = 50
    static let nervousAt: Double = 75
    static let panicAt: Double = 90

    /// Weekly pace: Tok worries when, at your current rate, you'd end the week at this
    /// percent of your limit. Only checked once you're this far into the week (seconds).
    static let paceNervousAt: Double = 110
    static let pacePanicAt: Double = 140
    static let paceMinElapsed: TimeInterval = 86400

    /// How long speech bubbles stay on screen (seconds).
    static let bubbleDuration: TimeInterval = 5

    /// Keychain item Claude Code stores its login in.
    static let keychainService = "Claude Code-credentials"

    /// Where "Open usage page" goes.
    static let usagePageURL = URL(string: "https://claude.ai/settings/usage")!
}

enum Mood: String, CaseIterable {
    case chill, busy, nervous, panic, sleeping, party, confused

    static func forPercent(_ p: Double) -> Mood {
        switch p {
        case 100...: return .sleeping
        case Config.panicAt...: return .panic
        case Config.nervousAt...: return .nervous
        case Config.busyAt...: return .busy
        default: return .chill
        }
    }

    /// How worried Tok is, for picking the more worried of two moods.
    var rank: Int {
        switch self {
        case .chill, .party, .confused: return 0
        case .busy: return 1
        case .nervous: return 2
        case .panic: return 3
        case .sleeping: return 4
        }
    }
}

/// Which limit Tok's ring and the menu bar follow. Auto picks weekly on Max 20x.
enum MainMeter: String, CaseIterable {
    case auto, session, weekly

    static let key = "mainMeter"
    static var saved: MainMeter {
        get { UserDefaults.standard.string(forKey: key).flatMap(MainMeter.init) ?? .auto }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    func weeklyFirst(plan: Plan?) -> Bool {
        switch self {
        case .auto: return plan?.weeklyFirst ?? false
        case .session: return false
        case .weekly: return true
        }
    }
}

/// How your weekly usage compares with how much of the week has gone by.
/// 40% used on day 1 is a lot; 40% used on day 6 is fine.
struct Pace: Equatable {
    static let window: TimeInterval = 7 * 86400

    /// Fraction of the week that has gone by, 0…1.
    let elapsed: Double
    /// Percent used minus percent of the week gone: positive means you're using it up faster than the week passes.
    let delta: Double
    /// Where you'd end the week at your current rate. Nil during the first day, when it's too jumpy to mean much.
    let projected: Double?
    /// When you'd run out at your current rate, if that's before the reset.
    let runsOutAt: Date?

    init?(meter: Meter, now: Date = Date()) {
        guard meter.id == "weekly", let resetsAt = meter.resetsAt else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        let elapsedSeconds = min(Self.window, max(0, Self.window - remaining))
        elapsed = elapsedSeconds / Self.window
        delta = meter.percent - elapsed * 100

        if elapsedSeconds >= Config.paceMinElapsed, meter.percent > 0 {
            let projected = meter.percent / elapsed
            self.projected = projected
            if projected > 100, meter.percent < 100 {
                let perSecond = meter.percent / elapsedSeconds
                runsOutAt = now.addingTimeInterval((100 - meter.percent) / perSecond)
            } else {
                runsOutAt = nil
            }
        } else {
            projected = nil
            runsOutAt = nil
        }
    }

    /// "on pace", "12% over pace", or "20% under pace".
    var summary: String {
        let points = Int(abs(delta).rounded())
        if delta > 5 { return "\(points)% over pace" }
        if delta < -5 { return "\(points)% under pace" }
        return "on pace"
    }

    /// How worried Tok should be about the pace alone (nil when it's fine).
    var mood: Mood? {
        guard let projected else { return nil }
        if projected >= Config.pacePanicAt { return .panic }
        if projected >= Config.paceNervousAt { return .nervous }
        return nil
    }
}

enum Palette {
    static let sage = Color(red: 0.45, green: 0.74, blue: 0.52)
    static let honey = Color(red: 0.95, green: 0.72, blue: 0.30)
    static let tangerine = Color(red: 0.95, green: 0.52, blue: 0.27)
    static let cherry = Color(red: 0.91, green: 0.31, blue: 0.31)

    static let clayLight = Color(red: 0.91, green: 0.56, blue: 0.42)
    static let clay = Color(red: 0.81, green: 0.43, blue: 0.31)
    static let clayDark = Color(red: 0.66, green: 0.33, blue: 0.23)
    static let ink = Color(red: 0.17, green: 0.10, blue: 0.08)
    static let blush = Color(red: 1.0, green: 0.55, blue: 0.62)
    static let sweat = Color(red: 0.58, green: 0.82, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.35)

    static func color(for percent: Double) -> Color {
        switch percent {
        case Config.panicAt...: return cherry
        case Config.nervousAt...: return tangerine
        case Config.busyAt...: return honey
        default: return sage
        }
    }
}

enum Format {
    static func countdown(to date: Date, from now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds < 60 { return "<1m" }
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        if h < 24 { return "\(h)h \(m % 60)m" }
        return "\(h / 24)d \(h % 24)h"
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(date) ? "h:mm a" : "EEE h:mm a"
        return f.string(from: date)
    }

    static func percent(_ p: Double) -> String { "\(Int(p.rounded()))%" }

    /// "$12.40", or "$50" when there are no cents.
    static func money(_ amount: Double, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        if amount == amount.rounded() { f.maximumFractionDigits = 0 }
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, currency)
    }
}
