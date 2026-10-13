import Foundation

/// Holidays and seasons Tok dresses up for. Every date is worked out on your Mac from the calendar
/// (Gregorian, Islamic, Hebrew, Chinese, and the moon), so new years need no app update.
enum Occasion: String, CaseIterable {
    case newYear, lunarNewYear, valentines, piDay, stPatricks, easter, earthDay
    case ramadan, eidAlFitr, eidAlAdha, independenceDay, tokBirthday
    case halloween, diwali, thanksgiving, hanukkah, christmas
    case spring, summer, autumn, winter

    var name: String {
        switch self {
        case .newYear: return "New Year"
        case .lunarNewYear: return "Lunar New Year"
        case .valentines: return "Valentine's Day"
        case .piDay: return "Pi Day"
        case .stPatricks: return "St. Patrick's Day"
        case .easter: return "Easter"
        case .earthDay: return "Earth Day"
        case .ramadan: return "Ramadan"
        case .eidAlFitr: return "Eid al-Fitr"
        case .eidAlAdha: return "Eid al-Adha"
        case .independenceDay: return "Fourth of July"
        case .tokBirthday: return "Tok's Birthday"
        case .halloween: return "Halloween"
        case .diwali: return "Diwali"
        case .thanksgiving: return "Thanksgiving"
        case .hanukkah: return "Hanukkah"
        case .christmas: return "Christmas"
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        }
    }

    var emoji: String {
        switch self {
        case .newYear: return "🥳"
        case .lunarNewYear: return "🧧"
        case .valentines: return "💕"
        case .piDay: return "🥧"
        case .stPatricks: return "☘️"
        case .easter: return "🐣"
        case .earthDay: return "🌱"
        case .ramadan, .eidAlFitr, .eidAlAdha: return "🌙"
        case .independenceDay: return "🎆"
        case .tokBirthday: return "🎂"
        case .halloween: return "🎃"
        case .diwali: return "🪔"
        case .thanksgiving: return "🦃"
        case .hanukkah: return "🕎"
        case .christmas: return "🎄"
        case .spring: return "🌸"
        case .summer: return "😎"
        case .autumn: return "🍂"
        case .winter: return "❄️"
        }
    }

    /// What Tok says the first time the outfit goes on. Seasons change quietly.
    var greeting: String? {
        switch self {
        case .newYear: return "happy new year!! 🥳"
        case .lunarNewYear: return "happy lunar new year! 🧧"
        case .valentines: return "you're my favorite human 💕"
        case .piDay: return "happy pi day! 3.14159… 🥧"
        case .stPatricks: return "feeling lucky! ☘️"
        case .easter: return "happy easter! 🐣"
        case .earthDay: return "happy earth day 🌱"
        case .ramadan: return "ramadan mubarak 🌙"
        case .eidAlFitr, .eidAlAdha: return "eid mubarak! 🌙✨"
        case .independenceDay: return "happy fourth of july! 🎆"
        case .tokBirthday: return "it's my birthday!! 🎂"
        case .halloween: return "spooky season! 🎃"
        case .diwali: return "happy diwali! 🪔"
        case .thanksgiving: return "thankful for you 🦃"
        case .hanukkah: return "happy hanukkah! 🕎"
        case .christmas: return "'tis the season! 🎄"
        case .spring, .summer, .autumn, .winter: return nil
        }
    }

    var isSeason: Bool { [.spring, .summer, .autumn, .winter].contains(self) }

    /// Fun extras lose to big holidays when they overlap (say, Pi Day during Ramadan).
    fileprivate var isMinor: Bool { [.valentines, .piDay, .stPatricks, .earthDay, .tokBirthday].contains(self) }
}

/// One stretch of days when Tok wears an outfit. `end` is the morning after the last day.
struct OccasionWindow {
    let occasion: Occasion
    let start: Date
    let end: Date

    var days: Int { OccasionCalendar.calendar.dateComponents([.day], from: start, to: end).day ?? 0 }
}

enum OccasionCalendar {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// The outfit for this moment. Holidays win over seasons; between two holidays, the big one wins,
    /// then the shorter one (so Diwali shows up during Halloween month). Turned-off occasions are skipped.
    static func current(at date: Date = Date(), region: String? = Locale.current.region?.identifier,
                        isEnabled: (Occasion) -> Bool = { _ in true }) -> OccasionWindow? {
        let year = calendar.component(.year, from: date)
        let active = (windows(in: year - 1, region: region) + windows(in: year, region: region))
            .filter { $0.start <= date && date < $0.end && isEnabled($0.occasion) }
        if let best = active.min(by: { ($0.occasion.isMinor ? 1 : 0, $0.days) < ($1.occasion.isMinor ? 1 : 0, $1.days) }) {
            return best
        }
        let season = season(at: date, region: region)
        return isEnabled(season.occasion) ? season : nil
    }

    /// Holidays that apply where you live. Most are everywhere; a few are national.
    static func occasions(for region: String?) -> [Occasion] {
        Occasion.allCases.filter { $0 != .independenceDay || region == "US" }
    }

    // MARK: Holiday dates

    private static var cache: [String: [OccasionWindow]] = [:]
    private static let cacheLock = NSLock()

    /// Every holiday window that starts in the given Gregorian year.
    static func windows(in year: Int, region: String?) -> [OccasionWindow] {
        let key = "\(year)-\(region ?? "")-\(TimeZone.current.identifier)"
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cache[key] { return cached }
        let result = computeWindows(in: year, region: region)
        cache[key] = result
        return result
    }

    private static func computeWindows(in year: Int, region: String?) -> [OccasionWindow] {
        let cal = calendar
        func day(_ month: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }
        func window(_ occasion: Occasion, from start: Date, days: Int) -> OccasionWindow {
            OccasionWindow(occasion: occasion, start: start, end: cal.date(byAdding: .day, value: days, to: start)!)
        }
        func window(_ occasion: Occasion, around center: Date, before: Int, after: Int) -> OccasionWindow {
            window(occasion, from: cal.date(byAdding: .day, value: -before, to: center)!, days: before + after + 1)
        }

        var list = [
            window(.newYear, from: day(12, 31), days: 2),
            window(.valentines, from: day(2, 10), days: 5),
            window(.piDay, from: day(3, 14), days: 1),
            window(.stPatricks, from: day(3, 15), days: 3),
            window(.easter, around: easterSunday(year), before: 7, after: 1),
            window(.earthDay, from: day(4, 22), days: 1),
            window(.tokBirthday, from: day(9, 30), days: 1),
            window(.halloween, from: day(10, 1), days: 31),
            window(.christmas, from: day(12, 1), days: 26),
        ]
        if region == "US" {
            list.append(window(.independenceDay, from: day(7, 1), days: 4))
        }
        // US: fourth Thursday of November. Canada: second Monday of October.
        if region == "CA" {
            list.append(window(.thanksgiving, around: nth(2, weekday: 2, month: 10, year: year), before: 3, after: 0))
        } else {
            list.append(window(.thanksgiving, around: nth(4, weekday: 5, month: 11, year: year), before: 6, after: 1))
        }
        if let newMoon = diwaliNewMoon(year) {
            list.append(window(.diwali, around: newMoon, before: 3, after: 2))
        }

        // Lunar calendars: walk the year once and note where their months begin.
        let islamic = Calendar(identifier: .islamicUmmAlQura)
        let hebrew = Calendar(identifier: .hebrew)
        let chinese = Calendar(identifier: .chinese)
        var date = day(1, 1)
        while cal.component(.year, from: date) == year {
            let i = islamic.dateComponents([.month, .day], from: date)
            if i.day == 1, i.month == 9 {
                let next = islamic.date(byAdding: .month, value: 1, to: islamic.startOfDay(for: date))
                let length = next.flatMap { cal.dateComponents([.day], from: date, to: $0).day } ?? 30
                list.append(window(.ramadan, from: date, days: length))
            }
            if i.day == 1, i.month == 10 { list.append(window(.eidAlFitr, from: date, days: 3)) }
            if i.day == 10, i.month == 12 { list.append(window(.eidAlAdha, from: date, days: 4)) }

            // Kislev is always month 3 in Foundation's Hebrew calendar.
            let h = hebrew.dateComponents([.month, .day], from: date)
            if h.day == 25, h.month == 3 { list.append(window(.hanukkah, from: date, days: 8)) }

            let c = chinese.dateComponents([.month, .day], from: date)
            if c.day == 1, c.month == 1, c.isLeapMonth != true {
                list.append(window(.lunarNewYear, around: date, before: 1, after: 3))
            }
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        return list
    }

    /// The nth given weekday (1 = Sunday) of a month.
    private static func nth(_ n: Int, weekday: Int, month: Int, year: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: n))!
    }

    /// Western Easter (the anonymous Gregorian algorithm).
    static func easterSunday(_ year: Int) -> Date {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Diwali falls on the new moon while the sun is in Tula (roughly Oct 17 to Nov 15), counted in India's time zone.
    static func diwaliNewMoon(_ year: Int) -> Date? {
        var india = Calendar(identifier: .gregorian)
        india.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        guard let from = india.date(from: DateComponents(year: year, month: 10, day: 17)),
              let to = india.date(from: DateComponents(year: year, month: 11, day: 16)) else { return nil }
        guard let moon = Moon.newMoons(from: from, to: to).first else { return nil }
        let d = india.dateComponents([.year, .month, .day], from: moon)
        return calendar.date(from: d)
    }

    // MARK: Seasons

    /// Places where December is summer.
    private static let southernHemisphere: Set<String> = [
        "AR", "AU", "BO", "BR", "BW", "CL", "FJ", "LS", "MG", "MU", "MZ", "NA", "NZ", "PE", "PY", "SZ", "UY", "ZA", "ZM", "ZW",
    ]

    static func season(at date: Date, region: String?) -> OccasionWindow {
        let cal = calendar
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        // Meteorological seasons: three whole months each, starting in March.
        let index = ((month - 3 + 12) % 12) / 3
        let march = cal.date(from: DateComponents(year: month < 3 ? year - 1 : year, month: 3, day: 1))!
        let start = cal.date(byAdding: .month, value: index * 3, to: march)!
        let end = cal.date(byAdding: .month, value: 3, to: start)!
        var seasons: [Occasion] = [.spring, .summer, .autumn, .winter]
        if let region, southernHemisphere.contains(region) { seasons = [.autumn, .winter, .spring, .summer] }
        return OccasionWindow(occasion: seasons[index], start: start, end: end)
    }
}

/// New moons from Jean Meeus, "Astronomical Algorithms" ch. 49, with the largest correction terms.
/// Good to well under an hour, which is plenty for picking a day.
enum Moon {
    static func newMoons(from: Date, to: Date) -> [Date] {
        let j2000 = Date(timeIntervalSince1970: 946_728_000)  // 2000-01-01 12:00 UTC
        let yearsSince2000 = from.timeIntervalSince(j2000) / (365.25 * 86400)
        var k = (yearsSince2000 * 12.3685).rounded(.down) - 1
        var result: [Date] = []
        while true {
            let moon = newMoon(k)
            if moon >= to { return result }
            if moon >= from { result.append(moon) }
            k += 1
        }
    }

    private static func newMoon(_ k: Double) -> Date {
        let t = k / 1236.85
        let rad = Double.pi / 180
        var jde = 2_451_550.09766 + 29.530588861 * k + 0.00015437 * t * t
        let e = 1 - 0.002516 * t
        let m = (2.5534 + 29.10535670 * k) * rad          // sun's mean anomaly
        let mp = (201.5643 + 385.81693528 * k) * rad      // moon's mean anomaly
        let f = (160.7108 + 390.67050284 * k) * rad       // moon's argument of latitude
        let omega = (124.7746 - 1.56375588 * k) * rad
        jde += -0.40720 * sin(mp) + 0.17241 * e * sin(m) + 0.01608 * sin(2 * mp) + 0.01039 * sin(2 * f)
            + 0.00739 * e * sin(mp - m) - 0.00514 * e * sin(mp + m) + 0.00208 * e * e * sin(2 * m)
            - 0.00111 * sin(mp - 2 * f) - 0.00057 * sin(mp + 2 * f) + 0.00056 * e * sin(2 * mp + m)
            - 0.00042 * sin(3 * mp) + 0.00042 * e * sin(m + 2 * f) - 0.00017 * sin(omega)
        // Julian day to Unix time (ignoring the ~1 minute between TT and UTC).
        return Date(timeIntervalSince1970: (jde - 2_440_587.5) * 86400)
    }
}

/// Choices from the menu bar's Holiday Outfits menu.
enum OutfitSettings {
    private static let onKey = "outfitsOn"
    private static let skippedKey = "outfitsSkipped"

    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: onKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: onKey) }
    }

    static func isEnabled(_ occasion: Occasion) -> Bool { !skipped.contains(occasion.rawValue) }

    static func toggle(_ occasion: Occasion) {
        var list = skipped
        if let index = list.firstIndex(of: occasion.rawValue) { list.remove(at: index) } else { list.append(occasion.rawValue) }
        UserDefaults.standard.set(list, forKey: skippedKey)
    }

    private static var skipped: [String] { UserDefaults.standard.stringArray(forKey: skippedKey) ?? [] }
}
