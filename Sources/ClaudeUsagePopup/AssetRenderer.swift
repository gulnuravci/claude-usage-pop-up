import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders the README images and app icon: `swift run ClaudeUsagePopup --render-assets assets`.
@MainActor
enum AssetRenderer {
    static func run(outputDirectory dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        renderGIF(to: dir.appendingPathComponent("demo.gif"))
        writePNG(renderMoods(), to: dir.appendingPathComponent("moods.png"))
        for scheme in [ColorScheme.light, .dark] {
            writePNG(renderWidget(scheme: scheme), to: dir.appendingPathComponent("widget-\(scheme == .dark ? "dark" : "light").png"))
        }
        writePNG(renderMini(), to: dir.appendingPathComponent("mini.png"))
        writePNG(renderIcon(), to: dir.appendingPathComponent("AppIcon.png"))
        print("Wrote assets to \(dir.path)")
    }

    // MARK: Demo GIF

    private struct Beat {
        let duration: Double
        let session: Double
        let weekly: Double
        var bubble: String?
        var party = false
    }

    private static let beats = [
        Beat(duration: 2.0, session: 23, weekly: 31),
        Beat(duration: 1.8, session: 58, weekly: 36),
        Beat(duration: 2.4, session: 81, weekly: 39, bubble: "psst… 81% of your 5h session used 👀"),
        Beat(duration: 2.2, session: 94, weekly: 41, bubble: "94% used — pace yourself! 🥵"),
        Beat(duration: 2.8, session: 100, weekly: 42, bubble: "out of tokens, nap time 😴 · back in 1h 12m"),
        Beat(duration: 3.2, session: 0, weekly: 42, bubble: "we're back!! fresh 5h block 🎉", party: true),
    ]

    private static func renderGIF(to url: URL) {
        let fps = 15.0
        let store = UsageStore()
        var frames: [CGImage] = []
        var previous = beats[0].session

        for beat in beats {
            for i in 0..<Int(beat.duration * fps) {
                let local = Double(i) / fps
                let ease = 1 - pow(1 - min(1, local / 0.5), 3)
                let percent = previous + (beat.session - previous) * ease
                store.setPreview(snapshot(session: percent, weekly: beat.weekly), bubble: beat.bubble, party: beat.party)
                let t = Double(frames.count) / fps + 0.6
                let view = backdrop(scheme: .dark) {
                    WidgetView(store: store)
                        .environment(\.frozenTime, t)
                        .environment(\.frozenConfetti, beat.party ? local : nil)
                }
                if let image = render(view, scale: 2) { frames.append(image) }
            }
            previous = beat.session
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
        for frame in frames { CGImageDestinationAddImage(destination, frame, frameProperties) }
        CGImageDestinationFinalize(destination)
    }

    // MARK: Stills

    private static func renderWidget(scheme: ColorScheme) -> CGImage? {
        let store = UsageStore()
        var snap = snapshot(session: 64, weekly: 38)
        snap.extras = [Meter(id: "scoped-0", label: "Opus · week", percent: 21, resetsAt: nil)]
        store.setPreview(snap, bubble: "boop! 64% used · resets in 2h 41m 🌿")
        return render(backdrop(scheme: scheme) { WidgetView(store: store).environment(\.frozenTime, 0.6) }, scale: 2)
    }

    private static func renderMini() -> CGImage? {
        let percents: [Double] = [23, 81, 100]
        let stores = percents.map { percent -> UsageStore in
            let store = UsageStore()
            store.setPreview(snapshot(session: percent, weekly: 40))
            return store
        }
        let row = HStack(spacing: 4) {
            ForEach(stores.indices, id: \.self) { i in
                WidgetView(store: stores[i], minimizedOverride: true)
            }
        }
        return render(backdrop(scheme: .dark) { row.environment(\.frozenTime, 0.7) }, scale: 2)
    }

    private static func renderMoods() -> CGImage? {
        let moods: [(Mood, Double, String)] = [
            (.chill, 20, "chill"), (.busy, 60, "busy"), (.nervous, 80, "nervous"),
            (.panic, 95, "panic"), (.sleeping, 100, "napping"), (.party, 100, "new block!"),
        ]
        let row = HStack(spacing: 22) {
            ForEach(moods, id: \.2) { mood, percent, label in
                VStack(spacing: 8) {
                    RingMascot(percent: percent, mood: mood).frame(width: 76, height: 76)
                    Text(label).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.16)))
        .environment(\.frozenTime, 0.7)
        return render(backdrop(scheme: .dark) { row }, scale: 2)
    }

    private static func renderIcon() -> CGImage? {
        let icon = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.95, blue: 0.9), Color(red: 0.98, green: 0.84, blue: 0.76)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            MascotView(mood: .chill)
                .frame(width: 640, height: 640)
                .offset(y: -20)
        }
        .frame(width: 1024, height: 1024)
        .environment(\.frozenTime, 0.5)
        return render(icon, scale: 1)
    }

    // MARK: Helpers

    private static func snapshot(session: Double, weekly: Double) -> UsageSnapshot {
        let now = Date()
        let sessionReset: TimeInterval = session >= 100 ? 4_350 : 9_690  // 1h 12m or 2h 41m, plus a little slack
        return UsageSnapshot(
            session: Meter(id: "session", label: "5h session", percent: session, resetsAt: now.addingTimeInterval(sessionReset)),
            weekly: Meter(id: "weekly", label: "Week", percent: weekly, resetsAt: now.addingTimeInterval(244_830))  // 2d 20h
        )
    }

    private static func backdrop<V: View>(scheme: ColorScheme, @ViewBuilder _ content: () -> V) -> some View {
        let dark: [Color] = [Color(red: 0.26, green: 0.22, blue: 0.36), Color(red: 0.42, green: 0.27, blue: 0.33)]
        let light: [Color] = [Color(red: 0.98, green: 0.91, blue: 0.86), Color(red: 0.90, green: 0.87, blue: 0.98)]
        let gradient = LinearGradient(colors: scheme == .dark ? dark : light, startPoint: .topLeading, endPoint: .bottomTrailing)
        return content()
            .padding(22)
            .background(gradient)
            .environment(\.snapshotMode, true)
            .environment(\.colorScheme, scheme)
    }

    private static func render<V: View>(_ view: V, scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }

    private static func writePNG(_ image: CGImage?, to url: URL) {
        guard let image, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("Failed to render \(url.lastPathComponent)")
            return
        }
        try? data.write(to: url)
    }
}
