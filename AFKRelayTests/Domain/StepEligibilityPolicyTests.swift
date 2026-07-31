import Foundation
import Testing
@testable import AFKRelay

@Suite("First step eligibility boundary")
struct StepEligibilityPolicyTests {
    @Test("First connection uses the current local calendar day")
    func localDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = Date(timeIntervalSince1970: 1_800_123_456)
        let boundary = StepEligibilityPolicy.firstConnectionBoundary(
            now: now,
            calendar: calendar
        )

        #expect(boundary == calendar.startOfDay(for: now))
        #expect(boundary <= now)
    }

    @Test("A later time-zone change cannot move the persisted absolute boundary")
    func timeZoneChange() throws {
        var originalCalendar = Calendar(identifier: .gregorian)
        originalCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laterCalendar = Calendar(identifier: .gregorian)
        laterCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = Date(timeIntervalSince1970: 1_800_123_456)
        let originalBoundary = StepEligibilityPolicy.firstConnectionBoundary(
            now: now,
            calendar: originalCalendar
        )
        let state = EconomyState(eligibilityStart: originalBoundary)
        let restored = try JSONDecoder().decode(
            EconomyState.self,
            from: JSONEncoder().encode(state)
        )

        #expect(restored.eligibilityStart == originalBoundary)
        #expect(
            restored.eligibilityStart
                != laterCalendar.startOfDay(for: now)
        )
    }
}
