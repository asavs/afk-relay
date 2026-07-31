import Foundation
import Testing
@testable import AFKRelay

@Suite("Economy ledger integration")
@MainActor
struct EconomyLedgerIntegrationTests {
    @Test("Refresh and movement interleave without overwriting either state")
    func refreshPlusSpend() async throws {
        let repository = ControlledSaveLedgerRepository(blockNextSave: true)
        let initial = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 100
        )
        let ledger = EconomyLedger(
            state: initial,
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )
        let interval = DateInterval(start: .distantPast, duration: 1)
        let refresh = Task { @MainActor in
            try await ledger.reconcile(
                StepTotal(
                    count: 200,
                    interval: interval,
                    observedAt: interval.end
                )
            )
        }

        await repository.waitUntilSaveStarts()
        #expect(ledger.commitMovement(distance: 43.2) == 43.2)
        await repository.releaseBlockedSave()
        #expect(try await refresh.value == 100)
        try await ledger.flush()

        let persisted = await repository.records.last?.state
        #expect(persisted?.observedStepHighWater == 200)
        #expect(persisted?.lifetimeStepsCredited == 200)
        #expect(persisted?.lifetimeTokensSpent == 1)
        #expect(ledger.state == persisted)
    }

    @Test("Failed reconciliation publishes no credit and retries exactly once")
    func failedCreditSave() async throws {
        let repository = ControlledSaveLedgerRepository(saveFails: true)
        let ledger = EconomyLedger(
            state: EconomyState(eligibilityStart: .distantPast),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )
        let interval = DateInterval(start: .distantPast, duration: 1)
        let total = StepTotal(
            count: 25,
            interval: interval,
            observedAt: interval.end
        )

        do {
            _ = try await ledger.reconcile(total)
            Issue.record("A failed candidate save must throw")
        } catch {
            #expect(error as? EconomyLedgerError == .persistenceFailed)
        }
        #expect(ledger.state.availableTokens == 0)
        #expect(ledger.persistenceFailure)

        await repository.setSaveFails(false)
        try await ledger.retryPersistence()
        #expect(try await ledger.reconcile(total) == 25)
        #expect(ledger.state.availableTokens == 25)
        #expect(await repository.records.last?.state.lifetimeStepsCredited == 25)
    }

    @Test("Failed zero-aggregate save publishes no connection evidence")
    func failedReadableZeroSave() async {
        let repository = ControlledSaveLedgerRepository(saveFails: true)
        let boundary = Date(timeIntervalSince1970: 1_000)
        let ledger = EconomyLedger(
            state: EconomyState(eligibilityStart: boundary),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )
        let interval = DateInterval(start: boundary, duration: 1)

        do {
            _ = try await ledger.reconcile(
                StepTotal(
                    count: 0,
                    interval: interval,
                    observedAt: interval.end
                )
            )
            Issue.record("A failed connection-evidence save must throw")
        } catch {
            #expect(error as? EconomyLedgerError == .persistenceFailed)
        }

        #expect(!ledger.state.hasReadableStepData)
        #expect(ledger.persistenceFailure)
    }

    @Test("Checkpoint failure prevents additional movement until retry")
    func spendingFailurePauses() async {
        let repository = ControlledSaveLedgerRepository(saveFails: true)
        var scheduled: (@MainActor @Sendable () async -> Void)?
        let ledger = EconomyLedger(
            state: EconomyState(
                eligibilityStart: .distantPast,
                lifetimeStepsCredited: 2
            ),
            repository: repository,
            scheduleCheckpoint: { _, operation in
                scheduled = operation
            }
        )

        _ = ledger.commitMovement(distance: 1)
        await scheduled?()

        #expect(ledger.persistenceFailure)
        #expect(ledger.commitMovement(distance: 1) == 0)
    }

    @Test("Explicit flush bounds force-quit rollback to the latest dirty state")
    func flushAndReload() async throws {
        let repository = InMemoryLedgerRepository()
        let ledger = EconomyLedger(
            state: EconomyState(
                eligibilityStart: .distantPast,
                lifetimeStepsCredited: 3
            ),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )

        _ = ledger.commitMovement(distance: 50)
        try await ledger.flush()
        let reloaded = try await EconomyLedger.load(
            repository: repository,
            eligibilityStart: .now
        )

        #expect(reloaded.state == ledger.state)
        #expect(reloaded.state.lifetimeTokensSpent == 1)
        #expect(abs(reloaded.state.movementRemainder - 6.8) < 0.000_001)
    }

    @Test(
        "A checkpoint waiter advances to a newer dirty revision",
        .timeLimit(.minutes(1))
    )
    func checkpointWaiterAdvancesRevision() async throws {
        let repository = ControlledSaveLedgerRepository(blockNextSave: true)
        let ledger = EconomyLedger(
            state: EconomyState(
                eligibilityStart: .distantPast,
                lifetimeStepsCredited: 2
            ),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )

        _ = ledger.commitMovement(distance: 1)
        let firstCheckpoint = Task { @MainActor in
            try await ledger.checkpoint()
        }
        await repository.waitUntilSaveStarts()

        _ = ledger.commitMovement(distance: 1)
        let newerCheckpoint = Task { @MainActor in
            try await ledger.checkpoint()
        }
        await Task.yield()
        await repository.releaseBlockedSave()

        try await firstCheckpoint.value
        try await newerCheckpoint.value

        let records = await repository.records
        #expect(records.count == 2)
        #expect(records.last?.state.movementRemainder == 2)
    }

    @Test("A refresh piling onto a failed save reports persistence failure")
    func pileUpOnFailedSaveReportsPersistenceFailure() async {
        let repository = ControlledSaveLedgerRepository(
            blockNextSave: true,
            saveFails: true
        )
        let ledger = EconomyLedger(
            state: EconomyState(eligibilityStart: .distantPast),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )
        let interval = DateInterval(start: .distantPast, duration: 1)
        let total = StepTotal(
            count: 50,
            interval: interval,
            observedAt: interval.end
        )

        let first = Task { @MainActor in
            try await ledger.reconcile(total)
        }
        await repository.waitUntilSaveStarts()
        let second = Task { @MainActor in
            try await ledger.reconcile(total)
        }
        await Task.yield()
        await repository.releaseBlockedSave()

        for refresh in [first, second] {
            do {
                _ = try await refresh.value
                Issue.record("A refresh over a failed save must throw")
            } catch {
                #expect(error as? EconomyLedgerError == .persistenceFailed)
            }
        }
        #expect(ledger.persistenceFailure)
        #expect(ledger.state.availableTokens == 0)
    }

    @Test("Malformed step totals fail closed")
    func malformedAggregate() async {
        let repository = InMemoryLedgerRepository()
        let ledger = EconomyLedger(
            state: EconomyState(eligibilityStart: .distantPast),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )
        let interval = DateInterval(start: .distantPast, duration: 1)
        let malformed = [
            StepTotal(
                count: -1,
                interval: interval,
                observedAt: interval.end
            ),
            StepTotal(
                count: 1,
                interval: interval,
                observedAt: interval.start
            ),
        ]

        for total in malformed {
            do {
                _ = try await ledger.reconcile(total)
                Issue.record("Malformed aggregate was accepted")
            } catch {
                #expect(error as? EconomyLedgerError == .invalidAggregate)
            }
        }
        #expect(ledger.state.availableTokens == 0)
    }
}

private actor ControlledSaveLedgerRepository: LedgerRepository {
    private(set) var records: [LedgerRecord] = []
    private var blockNextSave: Bool
    private var saveFails: Bool
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var saveStarted = false

    init(blockNextSave: Bool = false, saveFails: Bool = false) {
        self.blockNextSave = blockNextSave
        self.saveFails = saveFails
    }

    func load() -> LedgerRecord? {
        records.last
    }

    func save(_ record: LedgerRecord) async throws {
        saveStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        if blockNextSave {
            blockNextSave = false
            await withCheckedContinuation { continuation in
                saveContinuation = continuation
            }
        }
        if saveFails {
            throw LedgerPersistenceError.saveFailed
        }
        records.append(record)
    }

    func resetCorruptState(to baseline: LedgerRecord) {
        records = [baseline]
        saveFails = false
    }

    func waitUntilSaveStarts() async {
        if saveStarted { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseBlockedSave() {
        saveContinuation?.resume()
        saveContinuation = nil
    }

    func setSaveFails(_ value: Bool) {
        saveFails = value
    }
}
