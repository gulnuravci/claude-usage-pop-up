import AppKit

let arguments = CommandLine.arguments

if let index = arguments.firstIndex(of: "--render-assets") {
    let path = arguments.indices.contains(index + 1) ? arguments[index + 1] : "assets"
    MainActor.assumeIsolated { AssetRenderer.run(outputDirectory: URL(fileURLWithPath: path)) }
    exit(0)
}

if arguments.contains("--check") {
    // Prints your usage in the terminal: handy for checking that your login is found.
    Task {
        do {
            let snapshot = try await UsageAPI.fetch()
            for meter in [snapshot.session, snapshot.weekly].compactMap({ $0 }) + snapshot.extras {
                let reset = meter.resetsAt.map { "  (resets in \(Format.countdown(to: $0)))" } ?? ""
                print("\(meter.label): \(Format.percent(meter.percent))\(reset)")
            }
            exit(0)
        } catch {
            print("✗ \(error.localizedDescription)")
            exit(1)
        }
    }
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate(demo: arguments.contains("--demo")) }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
