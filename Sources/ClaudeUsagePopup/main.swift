import AppKit

let arguments = CommandLine.arguments

if let index = arguments.firstIndex(of: "--render-assets") {
    let path = arguments.indices.contains(index + 1) ? arguments[index + 1] : "assets"
    MainActor.assumeIsolated { AssetRenderer.run(outputDirectory: URL(fileURLWithPath: path)) }
    exit(0)
}

if let index = arguments.firstIndex(of: "--occasions") {
    // Lists the dates Tok dresses up for: `--occasions 2027`, or this year by default.
    let calendar = OccasionCalendar.calendar
    let year = arguments.indices.contains(index + 1) ? Int(arguments[index + 1]) : nil
    let region = Locale.current.region?.identifier
    let f = DateFormatter()
    f.dateFormat = "EEE MMM d, yyyy"
    for window in OccasionCalendar.windows(in: year ?? calendar.component(.year, from: Date()), region: region)
        .sorted(by: { $0.start < $1.start }) {
        let last = calendar.date(byAdding: .day, value: -1, to: window.end)!
        let range = window.days == 1 ? f.string(from: window.start) : "\(f.string(from: window.start)) – \(f.string(from: last))"
        print("\(window.occasion.emoji)  \(window.occasion.name.padding(toLength: 18, withPad: " ", startingAt: 0)) \(range)")
    }
    if let now = OccasionCalendar.current() { print("\nToday: \(now.occasion.emoji) \(now.occasion.name)") }
    exit(0)
}

if arguments.contains("--check") {
    // Prints your usage in the terminal: handy for checking that your login is found.
    Task {
        do {
            let snapshot = try await UsageAPI.fetch()
            for meter in snapshot.all {
                let reset = meter.resetsAt.map { "  (resets in \(Format.countdown(to: $0)))" } ?? ""
                print("\(meter.label): \(meter.amount ?? Format.percent(meter.percent))\(reset)")
            }
            exit(0)
        } catch {
            print("✗ \(error.localizedDescription)")
            exit(1)
        }
    }
    RunLoop.main.run()
}

// Try on an outfit any day of the year: `--outfit halloween`. A wrong name lists them all.
var forcedOutfit: Occasion?
if let index = arguments.firstIndex(of: "--outfit") {
    let name = arguments.indices.contains(index + 1) ? arguments[index + 1] : ""
    guard let occasion = Occasion.allCases.first(where: { $0.rawValue.lowercased() == name.lowercased() }) else {
        print("Unknown outfit \"\(name)\". Try one of: \(Occasion.allCases.map(\.rawValue).joined(separator: ", "))")
        exit(1)
    }
    forcedOutfit = occasion
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate(demo: arguments.contains("--demo"), outfit: forcedOutfit) }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
