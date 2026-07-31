import Foundation

/// Establishes the one-time absolute HealthKit eligibility boundary.
///
/// Later time-zone or calendar changes never recalculate a persisted boundary.
nonisolated enum StepEligibilityPolicy {
    static func firstConnectionBoundary(
        now: Date,
        calendar: Calendar
    ) -> Date {
        calendar.startOfDay(for: now)
    }
}
