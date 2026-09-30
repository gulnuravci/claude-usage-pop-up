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
}
