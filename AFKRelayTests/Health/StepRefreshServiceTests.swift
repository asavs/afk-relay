import Foundation
import Testing
@testable import AFKRelay

@Suite("Step refresh service")
@MainActor
struct StepRefreshServiceTests {
    @Test("Overlapping refreshes share one aggregate read and one submission")
    func coalescesOverlappingRefreshes() async throws {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )
        let reader = ControlledStepReader()
        let recorder = SubmissionRecorder()
        let service = StepRefreshService(
            reader: reader,
            intervalProvider: { interval },
            submit: { total in
                recorder.submit(total)
            }
        )

        let first = Task { try await service.refresh() }
        await reader.waitUntilQueryStarted()
        let second = Task { try await service.refresh() }
        await Task.yield()

        await reader.complete(
            with: StepTotal(
                count: 432,
                interval: interval,
                observedAt: interval.end
            )
        )

        let firstResult = try await first.value
        let secondResult = try await second.value

        #expect(firstResult == secondResult)
        #expect(firstResult.newlyCreditedTokens == 432)
        #expect(await reader.queryCount == 1)
        #expect(recorder.submissionCount == 1)
    }

    @Test("Onboarding refresh requests access before reading")
    func requestsAccessDuringOnboarding() async throws {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20)
        )
        let reader = ImmediateStepReader(
            result: StepTotal(count: 12, interval: interval, observedAt: interval.end)
        )
        let recorder = SubmissionRecorder()
        let service = StepRefreshService(
            reader: reader,
            intervalProvider: { interval },
            submit: { total in recorder.submit(total) }
        )

        _ = try await service.refresh(requestAccess: true)

        #expect(await reader.accessRequestCount == 1)
        #expect(await reader.queryCount == 1)
        #expect(recorder.submissionCount == 1)
    }
}

@MainActor
private final class SubmissionRecorder {
    private(set) var submissionCount = 0

    func submit(_ total: StepTotal) -> Int64 {
        submissionCount += 1
        return total.count
    }
}

private actor ImmediateStepReader: StepTotalReading {
    let result: StepTotal
    private(set) var accessRequestCount = 0
    private(set) var queryCount = 0

    init(result: StepTotal) {
        self.result = result
    }

    func requestAccess() {
        accessRequestCount += 1
    }

    func cumulativeSteps(in interval: DateInterval) -> StepTotal {
        queryCount += 1
        return result
    }
}

private actor ControlledStepReader: StepTotalReading {
    private(set) var queryCount = 0
    private var queryStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var resultContinuation: CheckedContinuation<StepTotal, any Error>?

    func requestAccess() {}

    func cumulativeSteps(in interval: DateInterval) async throws -> StepTotal {
        queryCount += 1
        queryStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        return try await withCheckedThrowingContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitUntilQueryStarted() async {
        if queryStarted {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func complete(with result: StepTotal) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}
