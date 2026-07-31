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

    @Test("An access-requesting refresh does not join a non-requesting one")
    func accessRequestSurvivesCoalescing() async throws {
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
        let total = StepTotal(
            count: 100,
            interval: interval,
            observedAt: interval.end
        )

        let plain = Task { try await service.refresh() }
        await reader.waitUntilQueryStarted()
        let requesting = Task { try await service.refresh(requestAccess: true) }
        await Task.yield()

        await reader.complete(with: total)
        _ = try await plain.value

        // The access-requesting caller must run its own pass with the
        // native request instead of adopting the plain result.
        await reader.waitUntilQueryCount(2)
        await reader.complete(with: total)
        _ = try await requesting.value

        #expect(await reader.accessRequestCount == 1)
        #expect(await reader.queryCount == 2)
        #expect(recorder.submissionCount == 2)
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
    private(set) var accessRequestCount = 0
    private(set) var queryCount = 0
    private var startWaiters:
        [(threshold: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var resultContinuation: CheckedContinuation<StepTotal, any Error>?

    func requestAccess() {
        accessRequestCount += 1
    }

    func cumulativeSteps(in interval: DateInterval) async throws -> StepTotal {
        queryCount += 1
        let reached = startWaiters.filter { $0.threshold <= queryCount }
        startWaiters.removeAll { $0.threshold <= queryCount }
        for waiter in reached {
            waiter.continuation.resume()
        }

        return try await withCheckedThrowingContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitUntilQueryStarted() async {
        await waitUntilQueryCount(1)
    }

    func waitUntilQueryCount(_ threshold: Int) async {
        if queryCount >= threshold {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append((threshold, continuation))
        }
    }

    func complete(with result: StepTotal) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}
