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
