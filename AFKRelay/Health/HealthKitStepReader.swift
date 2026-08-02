import Foundation
import HealthKit

nonisolated enum HealthKitStepReaderError: Error, Equatable, Sendable {
    case healthDataUnavailable
    case stepTypeUnavailable
    case noReadableStepData
    case invalidAggregate
}

/// The only adapter allowed to expose HealthKit to the application. Its
/// output is a validated merged aggregate, never samples or source metadata.
@MainActor
final class HealthKitStepReader: StepTotalReading {
    private let healthStore: HKHealthStore
    private let now: @MainActor @Sendable () -> Date

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        now: @escaping @MainActor @Sendable () -> Date = { .now }
    ) {
        self.healthStore = healthStore
        self.now = now
    }

    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitStepReaderError.healthDataUnavailable
        }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitStepReaderError.stepTypeUnavailable
        }

        // HealthKit deliberately does not reveal read-denial status. Success
        // here means only that the authorization request completed.
        try await healthStore.requestAuthorization(
            toShare: Set<HKSampleType>(),
            read: Set<HKObjectType>([stepType])
        )
    }

    func cumulativeSteps(in interval: DateInterval) async throws -> StepTotal {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitStepReaderError.healthDataUnavailable
        }
        guard interval.duration >= 0 else {
            throw HealthKitStepReaderError.invalidAggregate
        }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitStepReaderError.stepTypeUnavailable
        }

        let samplePredicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: [.strictStartDate]
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: samplePredicate),
            options: [.cumulativeSum]
        )
        let statistics = try await descriptor.result(for: healthStore)

        guard let sum = statistics?.sumQuantity() else {
            // An empty result means one of two things, and HealthKit refuses
            // to say which: access was denied, or the window genuinely holds
            // no samples. Treating both as "cannot read" walls off anyone who
            // connects before walking — first thing in the morning, the
            // eligibility window starts at midnight and is usually empty.
            //
            // A wider look-back separates them. History means reading works,
            // so an empty window is a true zero. Only a store that yields
            // nothing at all is unreadable.
            if try await hasReadableHistory(stepType: stepType) {
                return StepTotal(
                    count: 0,
                    interval: interval,
                    observedAt: await now()
                )
            }
            throw HealthKitStepReaderError.noReadableStepData
        }

        let rawCount = sum.doubleValue(for: .count())
        guard rawCount.isFinite, rawCount >= 0, rawCount <= Double(Int64.max) else {
            throw HealthKitStepReaderError.invalidAggregate
        }

        return StepTotal(
            count: Int64(rawCount.rounded(.down)),
            interval: interval,
            observedAt: await now()
        )
    }

    /// Whether the store yields any step sample at all over a long look-back.
    ///
    /// Read-only evidence that reading is permitted, never a minting input:
    /// the caller's aggregate is still bounded by the eligibility interval, so
    /// no historical step can be credited by this query existing.
    private func hasReadableHistory(stepType: HKQuantityType) async throws -> Bool {
        let end = await now()
        let start = end.addingTimeInterval(-Self.historyLookBack)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(
                type: stepType,
                predicate: HKQuery.predicateForSamples(
                    withStart: start,
                    end: end,
                    options: [.strictStartDate]
                )
            ),
            options: [.cumulativeSum]
        )
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity() != nil
    }

    /// Thirty days, matching the window the bank gauge already reads, so a
    /// dormant phone is not mistaken for a denied one.
    private static let historyLookBack: TimeInterval = 30 * 24 * 60 * 60

    func averageDailySteps(
        over interval: DateInterval,
        calendar: Calendar
    ) async throws -> Int64 {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitStepReaderError.healthDataUnavailable
        }
        guard interval.duration > 0 else {
            throw HealthKitStepReaderError.invalidAggregate
        }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitStepReaderError.stepTypeUnavailable
        }

        let samplePredicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: [.strictStartDate]
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: stepType, predicate: samplePredicate),
            options: [.cumulativeSum],
            anchorDate: calendar.startOfDay(for: interval.start),
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: healthStore)

        // Empty days count as zero, matching how Health's own charts
        // average a period.
        var dayCount = 0
        var total = 0.0
        collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
            dayCount += 1
            total += statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
        }

        guard dayCount > 0, total.isFinite, total >= 0,
              total <= Double(Int64.max)
        else {
            return 0
        }
        return Int64((total / Double(dayCount)).rounded(.down))
    }
}
