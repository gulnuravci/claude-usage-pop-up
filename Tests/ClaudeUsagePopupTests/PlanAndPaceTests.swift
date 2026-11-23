import XCTest
@testable import ClaudeUsagePopup

final class PlanTests: XCTestCase {
    func testDetectFromRateLimitTier() {
        XCTAssertEqual(Plan.detect(tier: "default_claude_max_20x", subscription: "max"), .max20x)
        XCTAssertEqual(Plan.detect(tier: "default_claude_max_5x", subscription: "max"), .max5x)
        XCTAssertEqual(Plan.detect(tier: nil, subscription: "pro"), .pro)
        XCTAssertEqual(Plan.detect(tier: "default_claude_ai", subscription: "pro"), .pro)
        XCTAssertEqual(Plan.detect(tier: nil, subscription: "max"), .max5x)
        XCTAssertEqual(Plan.detect(tier: nil, subscription: nil), .unknown)
        XCTAssertEqual(Plan.detect(tier: nil, subscription: "enterprise"), .unknown)
    }

    func testOnlyMax20xLeadsWithWeekly() {
        XCTAssertTrue(Plan.max20x.weeklyFirst)
        for plan in [Plan.pro, .max5x, .unknown] { XCTAssertFalse(plan.weeklyFirst) }
    }

    func testCredentialsParseReadsTier() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"abc","expiresAt":1700000000000,"subscriptionType":"max","rateLimitTier":"default_claude_max_20x"}}"#
        let token = try XCTUnwrap(Credentials.parse(Data(json.utf8)))
        XCTAssertEqual(token.accessToken, "abc")
        XCTAssertEqual(token.plan, .max20x)
    }

    func testCredentialsParseWithoutTier() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"abc"}}"#
        XCTAssertEqual(try XCTUnwrap(Credentials.parse(Data(json.utf8))).plan, .unknown)
    }

    func testMainMeterSetting() {
        XCTAssertTrue(MainMeter.auto.weeklyFirst(plan: .max20x))
        XCTAssertFalse(MainMeter.auto.weeklyFirst(plan: .max5x))
        XCTAssertFalse(MainMeter.auto.weeklyFirst(plan: nil))
        XCTAssertFalse(MainMeter.session.weeklyFirst(plan: .max20x))
        XCTAssertTrue(MainMeter.weekly.weeklyFirst(plan: .pro))
    }
}

final class SnapshotTests: XCTestCase {
    let session = Meter(id: "session", label: "5h session", percent: 12, resetsAt: nil)
    let weekly = Meter(id: "weekly", label: "Week", percent: 42, resetsAt: nil)

    func testPrimaryAndOrder() {
        let snap = UsageSnapshot(session: session, weekly: weekly)
        XCTAssertEqual(snap.primary(weeklyFirst: true)?.id, "weekly")
        XCTAssertEqual(snap.primary(weeklyFirst: false)?.id, "session")
        XCTAssertEqual(snap.mainMeters(weeklyFirst: true).map(\.id), ["weekly", "session"])
        XCTAssertEqual(snap.mainMeters(weeklyFirst: false).map(\.id), ["session", "weekly"])
    }

    func testPrimaryFallsBackWhenMissing() {
        XCTAssertEqual(UsageSnapshot(session: session, weekly: nil).primary(weeklyFirst: true)?.id, "session")
        XCTAssertEqual(UsageSnapshot(session: nil, weekly: weekly).primary(weeklyFirst: false)?.id, "weekly")
    }

    func testBlockedUntilUsesLatestFullMeter() {
        let now = Date()
        var snap = UsageSnapshot(session: session, weekly: weekly)
        XCTAssertNil(snap.blockedUntil)
        snap.session = Meter(id: "session", label: "", percent: 100, resetsAt: now.addingTimeInterval(3600))
        XCTAssertEqual(snap.blockedUntil, now.addingTimeInterval(3600))
        snap.weekly = Meter(id: "weekly", label: "", percent: 100, resetsAt: now.addingTimeInterval(86400))
        XCTAssertEqual(snap.blockedUntil, now.addingTimeInterval(86400))
    }

    func testOldCacheWithoutPlanStillDecodes() throws {
        let json = #"{"session":{"id":"session","label":"5h session","percent":10},"extras":[]}"#
        let snap = try JSONDecoder().decode(UsageSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snap.plan)
        XCTAssertEqual(snap.session?.percent, 10)
    }
}

final class PaceTests: XCTestCase {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let day: TimeInterval = 86400

    /// A weekly meter `daysIn` days into its 7-day window.
    func weekly(_ percent: Double, daysIn: Double) -> Meter {
        Meter(id: "weekly", label: "Week", percent: percent, resetsAt: now.addingTimeInterval((7 - daysIn) * day))
    }

    func testOnlyWeeklyMetersWithAResetHavePace() {
        XCTAssertNil(Pace(meter: Meter(id: "session", label: "", percent: 50, resetsAt: now.addingTimeInterval(3600)), now: now))
        XCTAssertNil(Pace(meter: Meter(id: "weekly", label: "", percent: 50, resetsAt: nil), now: now))
        XCTAssertNil(Pace(meter: Meter(id: "weekly", label: "", percent: 50, resetsAt: now.addingTimeInterval(-60)), now: now))
    }

    func testElapsedAndSummary() throws {
        let half = try XCTUnwrap(Pace(meter: weekly(50, daysIn: 3.5), now: now))
        XCTAssertEqual(half.elapsed, 0.5, accuracy: 0.0001)
        XCTAssertEqual(half.summary, "on pace")

        XCTAssertEqual(Pace(meter: weekly(62, daysIn: 3.5), now: now)?.summary, "12% over pace")
        XCTAssertEqual(Pace(meter: weekly(30, daysIn: 3.5), now: now)?.summary, "20% under pace")
    }

    func testProjectionWaitsForFirstDay() throws {
        let early = try XCTUnwrap(Pace(meter: weekly(20, daysIn: 0.5), now: now))
        XCTAssertNil(early.projected)
        XCTAssertNil(early.runsOutAt)
        XCTAssertNil(early.mood)
    }

    func testRunOutEstimate() throws {
        // 60% in 2 days = 30%/day, so the last 40% lasts another 1⅓ days.
        let pace = try XCTUnwrap(Pace(meter: weekly(60, daysIn: 2), now: now))
        XCTAssertEqual(try XCTUnwrap(pace.projected), 210, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(pace.runsOutAt).timeIntervalSince(now), 4 * day / 3, accuracy: 1)
        XCTAssertEqual(pace.mood, .panic)
    }

    func testNoRunOutWhenUnderPace() throws {
        let pace = try XCTUnwrap(Pace(meter: weekly(40, daysIn: 5), now: now))
        XCTAssertNil(pace.runsOutAt)
        XCTAssertNil(pace.mood)
    }

    func testPaceMoodThresholds() {
        // projected = percent / elapsed; at 3.5 days in, projected = percent * 2.
        XCTAssertNil(Pace(meter: weekly(52, daysIn: 3.5), now: now)?.mood)          // 104%
        XCTAssertEqual(Pace(meter: weekly(56, daysIn: 3.5), now: now)?.mood, .nervous) // 112%
        XCTAssertEqual(Pace(meter: weekly(71, daysIn: 3.5), now: now)?.mood, .panic)   // 142%
    }

    func testMoodRanking() {
        XCTAssertGreaterThan(Mood.panic.rank, Mood.nervous.rank)
        XCTAssertGreaterThan(Mood.sleeping.rank, Mood.panic.rank)
        XCTAssertGreaterThan(Mood.nervous.rank, Mood.chill.rank)
    }
}
