import AppKit
import SwiftUI

/// The floating card: mascot inside a progress ring, plus a row per limit.
/// Minimized, it's just Tok in the ring with a tiny percent tag.
struct WidgetView: View {
    @ObservedObject var store: UsageStore
    var dragger: WindowDragger?
    var onHide: () -> Void = {}
    /// Lets the asset renderer draw either mode regardless of the saved setting.
    var minimizedOverride: Bool?

    @AppStorage("widgetMinimized") private var minimizedSetting = false
    @State private var hovering = false

    /// Empty space above the card for speech bubbles and confetti to live in.
    static let headroom: CGFloat = 36
    static let cardPadding: CGFloat = 12
    static let ringSize: CGFloat = 70
    static let miniRingSize: CGFloat = 58
    static let miniPadding: CGFloat = 7

    private var minimized: Bool { minimizedOverride ?? minimizedSetting }

    var body: some View {
        Group {
            if minimized { miniWidget } else { fullWidget }
        }
        .onHover { hovering = $0 }
    }

    // MARK: Full card

    private var fullWidget: some View {
        card
            .padding(.top, Self.headroom)
            .overlay(alignment: .topLeading) { bubble }
            .overlay {
                ConfettiView(trigger: store.confettiCount) { size in
                    CGPoint(x: Self.cardPadding + Self.ringSize / 2,
                            y: Self.headroom + (size.height - Self.headroom) / 2)
                }
            }
            .padding(10)
            .frame(width: 290)
    }

    private var card: some View {
        HStack(spacing: 14) {
            RingMascot(percent: sessionPercent, mood: store.mood)
                .frame(width: Self.ringSize, height: Self.ringSize)
                .contentShape(Circle())
                .onTapGesture { store.poke() }
                .help("Click me to refresh")
            details
        }
        .padding(Self.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground())
        .overlay(alignment: .topTrailing) { staleBadge }
        .overlay(alignment: .topLeading) {
            cornerButton("minus", help: "Minimize") { minimizedSetting = true }
        }
        .modifier(ShakeEffect(shakes: CGFloat(store.shakeCount)))
        .gesture(dragGesture)
        .contextMenu { menuItems }
    }

    // MARK: Minimized

    private var miniWidget: some View {
        RingMascot(percent: sessionPercent, mood: store.mood)
            .frame(width: Self.miniRingSize, height: Self.miniRingSize)
            .padding(Self.miniPadding)
            .background(CardBackground(radius: Self.miniRingSize / 2 + Self.miniPadding))
            .contentShape(Circle())
            .onTapGesture { minimizedSetting = false }
            .help(miniTooltip)
            .overlay(alignment: .bottom) { percentTag.offset(y: 7) }
            .overlay(alignment: .topLeading) {
                cornerButton("arrow.up.left.and.arrow.down.right", help: "Expand") { minimizedSetting = false }
            }
            .modifier(ShakeEffect(shakes: CGFloat(store.shakeCount)))
            .gesture(dragGesture)
            .contextMenu { menuItems }
            .padding(.top, 14)
            .padding(.bottom, 8)
            .overlay {
                ConfettiView(trigger: store.confettiCount) { size in
                    CGPoint(x: size.width / 2, y: 14 + Self.miniPadding + Self.miniRingSize / 2)
                }
            }
            .padding(10)
    }

    @ViewBuilder private var percentTag: some View {
        if let session = store.snapshot?.session {
            let text = session.percent >= 100
                ? session.resetsAt.map { "💤 " + Format.countdown(to: $0) } ?? "💤"
                : Format.percent(session.percent)
            Text(text)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(store.mood == .party ? Palette.sage : Palette.color(for: session.percent)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                .fixedSize()
        }
    }

    private var miniTooltip: String {
        guard let snapshot = store.snapshot else { return store.error?.localizedDescription ?? "Click to expand" }
        let lines = [snapshot.session, snapshot.weekly].compactMap { $0 }.map { meter in
            "\(meter.label): \(Format.percent(meter.percent))" + (meter.resetsAt.map { ", resets in \(Format.countdown(to: $0))" } ?? "")
        }
        return (lines + ["Click to expand"]).joined(separator: "\n")
    }

    // MARK: Shared bits

    private var sessionPercent: Double { store.snapshot?.session?.percent ?? 0 }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in dragger?.dragChanged() }
            .onEnded { _ in dragger?.dragEnded() }
    }

    @ViewBuilder private var menuItems: some View {
        Button(minimized ? "Expand" : "Minimize") { minimizedSetting.toggle() }
        Button("Refresh now") { store.refreshNow() }
        Button("Open usage page") { NSWorkspace.shared.open(Config.usagePageURL) }
        Divider()
        Button("Hide widget") { onHide() }
    }

    /// A little round button that peeks out of the top-left corner on hover.
    private func cornerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 7.5, weight: .heavy))
                .foregroundStyle(.secondary)
                .frame(width: 17, height: 17)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .offset(x: -5, y: -5)
        .opacity(hovering ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    @ViewBuilder private var details: some View {
        if let snapshot = store.snapshot {
            VStack(alignment: .leading, spacing: 7) {
                if let session = snapshot.session { MeterRow(meter: session) }
                if let weekly = snapshot.weekly { MeterRow(meter: weekly) }
                ForEach(snapshot.extras) { MeterRow(meter: $0, compact: true) }
            }
        } else if let error = store.error {
            VStack(alignment: .leading, spacing: 3) {
                Text("Can't see your usage")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(error.localizedDescription)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Peeking at your usage…")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var staleBadge: some View {
        if let error = store.error, store.snapshot != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(Palette.honey)
                .padding(7)
                .help(error.localizedDescription)
        }
    }

    @ViewBuilder private var bubble: some View {
        if let bubble = store.bubble {
            BubbleView(text: bubble.text)
                .padding(.leading, 4)
                .id(bubble.id)
                .transition(.scale(scale: 0.4, anchor: .bottomLeading).combined(with: .opacity))
        }
    }
}

struct RingMascot: View {
    let percent: Double
    let mood: Mood
    @Environment(\.frozenTime) private var frozenTime

    private let lineWidth: CGFloat = 5.5

    var body: some View {
        let color = mood == .party ? Palette.sage : Palette.color(for: percent)
        ZStack {
            Circle().stroke(Color.primary.opacity(0.09), lineWidth: lineWidth)
            glowingArc(color: color)
            MascotView(mood: mood).padding(lineWidth - 3)
        }
    }

    @ViewBuilder private func glowingArc(color: Color) -> some View {
        let arc = Circle()
            .trim(from: 0, to: max(0.001, min(percent, 100) / 100))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .opacity(percent < 0.5 ? 0 : 1)
            .animation(.spring(response: 0.8, dampingFraction: 0.75), value: percent)
        if mood == .nervous || mood == .panic {
            // Pulse a glow when you're close to the limit.
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                let t = frozenTime ?? context.date.timeIntervalSinceReferenceDate
                let pulse = 0.5 + 0.5 * sin(t * (mood == .panic ? 7 : 4))
                arc.shadow(color: color.opacity(0.4 + 0.5 * pulse), radius: 2 + 5 * pulse)
            }
        } else {
            arc
        }
    }
}

struct MeterRow: View {
    let meter: Meter
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(meter.label)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(Format.percent(meter.percent))
                    .font(.system(size: compact ? 11 : 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.color(for: meter.percent))
            }
            ProgressBar(percent: meter.percent, height: compact ? 4 : 5)
            if !compact, let resetsAt = meter.resetsAt {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    Text(resetText(resetsAt, now: context.date))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private func resetText(_ date: Date, now: Date) -> String {
        let countdown = Format.countdown(to: date, from: now)
        return meter.percent >= 100 ? "back in \(countdown) 💤" : "resets in \(countdown)"
    }
}

struct ProgressBar: View {
    let percent: Double
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(Palette.color(for: percent))
                    .frame(width: max(height, geo.size.width * min(percent, 100) / 100))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percent)
    }
}

struct BubbleView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white))
            BubbleTail()
                .fill(Color.white)
                .frame(width: 10, height: 6)
                .padding(.leading, 28)
        }
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .frame(maxWidth: 270, alignment: .leading)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A quick side-to-side wobble each time `shakes` goes up by one.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(shakes * .pi * 6) * 5, y: 0))
    }
}

struct CardBackground: View {
    var radius: CGFloat = 20
    @Environment(\.snapshotMode) private var snapshotMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(0.28)).blur(radius: 8).offset(y: 3).padding(3)
            if snapshotMode {
                shape.fill(colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.97))
            } else {
                VisualEffectBackground(radius: radius)
            }
            shape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.5), lineWidth: 1)
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let radius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.roundedMask(radius: radius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
