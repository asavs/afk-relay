import Foundation

nonisolated struct StepRefreshResult: Equatable, Sendable {
    let newlyCreditedTokens: Int64
    let observedAt: Date
}

/// Coalesces foreground, onboarding, and manual refresh triggers. The service
/// reads one aggregate and submits it through the injected single-writer ledger
/// boundary; it never publishes an unsaved balance itself.
@MainActor
final class StepRefreshService {
    typealias IntervalProvider = @MainActor @Sendable () throws -> DateInterval
    typealias Submission = @MainActor @Sendable (StepTotal) async throws -> Int64

    private let reader: any StepTotalReading
    private let intervalProvider: IntervalProvider
    private let submit: Submission
    private var inFlight: Task<StepRefreshResult, any Error>?

    init(
        reader: any StepTotalReading,
        intervalProvider: @escaping IntervalProvider,
        submit: @escaping Submission
    ) {
        self.reader = reader
        self.intervalProvider = intervalProvider
        self.submit = submit
    }

    func refresh(requestAccess: Bool = false) async throws -> StepRefreshResult {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task { @MainActor [reader, intervalProvider, submit] in
            if requestAccess {
                try await reader.requestAccess()
            }

            let interval = try intervalProvider()
            let total = try await reader.cumulativeSteps(in: interval)
            let newlyCreditedTokens = try await submit(total)
            return StepRefreshResult(
                newlyCreditedTokens: newlyCreditedTokens,
                observedAt: total.observedAt
            )
        }

        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    func cancel() {
        inFlight?.cancel()
        inFlight = nil
    }
}
