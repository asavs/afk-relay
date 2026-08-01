import Foundation
import Testing
@testable import AFKRelay

@Suite("Economy domain")
struct EconomyDomainTests {
    @Test(arguments: [Int64(0), 1, 42, 9_999])
    func balanceAndExactCredit(steps: Int64) {
        let balance = MVPBalance.v2
        #expect(balance.arenaSize == .init(x: 800, y: 1200))
        #expect(balance.playerRadius == 36)
        #expect(balance.playerSpeed == 240)
        #expect(balance.playerHitPoints == 3)
        #expect(balance.movementDistancePerToken == 43.2)
        #expect(balance.enemyRadius == 34)
        #expect(balance.enemySpeed == 90)
        #expect(balance.tutorialEnemySpeed == 75)
        #expect(balance.enemyHitPoints == 2)
        #expect(balance.sweepTriggerDistance == 200)
        #expect(balance.sweepReach == 190)
        #expect(balance.sweepArcDegrees == 120)
        #expect(balance.sweepBladeDegrees == 28)
        #expect(balance.sweepTelegraphDuration == 1)
        #expect(balance.sweepActiveDuration == 0.45)
        #expect(balance.sweepRecoveryDuration == 0.75)
        #expect(balance.sweepDamage == 1)
        #expect(balance.spawnInitialInterval == 4)
        #expect(balance.spawnMinimumInterval == 1.5)
        #expect(balance.spawnRampDuration == 180)
        #expect(balance.enemyCap == 20)
        var state = EconomyState(eligibilityStart: .distantPast)
        #expect(state.reconcile(observedSteps: steps) == steps)
        #expect(state.availableTokens == steps)
        #expect(state.reconcile(observedSteps: steps) == 0)
    }

    @Test("Repeated and downward Health revisions never mint twice")
    func revisions() {
        var state = EconomyState(eligibilityStart: .distantPast)
        #expect(state.reconcile(observedSteps: 100) == 100)
        #expect(state.reconcile(observedSteps: 80) == 0)
        #expect(state.observedStepHighWater == 100)
        #expect(state.reconcile(observedSteps: 125) == 25)
        #expect(state.lifetimeStepsCredited == 125)
    }

    @Test("Five thousand tokens fund exactly fifteen minutes at full speed")
    func lockedMovementExchange() {
        let balance = MVPBalance.v2
        let seconds = Double(5_000) * balance.movementDistancePerToken
            / balance.playerSpeed
        let burnRate = balance.playerSpeed
            / balance.movementDistancePerToken

        #expect(seconds == 15 * 60)
        #expect(abs(burnRate - 5.555_555_555_555_556) < 0.000_000_001)
    }

    @Test("Partial movement affordability and fractional carry")
    func movement() {
        var state = EconomyState(eligibilityStart: .distantPast, lifetimeStepsCredited: 1)
        #expect(MovementCostPolicy.commit(distance: 20, state: &state) == 20)
        #expect(state.lifetimeTokensSpent == 0)
        #expect(state.movementRemainder == 20)
        #expect(abs(MovementCostPolicy.reserve(distance: 100, state: state).affordableDistance - 23.2) < 0.000_001)
        #expect(abs(MovementCostPolicy.commit(distance: 100, state: &state) - 23.2) < 0.000_001)
        #expect(state.availableTokens == 0)
        #expect(abs(state.movementRemainder) < 0.000_001)
        #expect(MovementCostPolicy.commit(distance: 0, state: &state) == 0)
    }

    @Test("Diagonal distance is charged by length")
    func diagonal() {
        var state = EconomyState(eligibilityStart: .distantPast, lifetimeStepsCredited: 2)
        let distance = Vector2(x: 30, y: 40).length
        #expect(MovementCostPolicy.commit(distance: distance, state: &state) == 50)
        #expect(abs(state.movementRemainder - 6.8) < 0.000_001)
    }

    @Test("Ledger saves reconciliation candidate before publishing") @MainActor
    func saveBeforePublish() async throws {
        let repo = RecordingLedgerRepository()
        let ledger = EconomyLedger(
            state: .init(eligibilityStart: .distantPast),
            repository: repo,
            scheduleCheckpoint: { _, operation in
                Task { @MainActor in await operation() }
            }
        )
        let total = StepTotal(count: 4, interval: .init(start: .distantPast, duration: 1), observedAt: .now)
        #expect(try await ledger.reconcile(total) == 4)
        #expect(await repo.records.last?.state.lifetimeStepsCredited == 4)
        #expect(ledger.state.lifetimeStepsCredited == 4)
    }

    @Test("A readable zero aggregate durably completes step connection")
    @MainActor
    func readableZeroAggregate() async throws {
        let repository = InMemoryLedgerRepository()
        let boundary = Date(timeIntervalSince1970: 1_000)
        let ledger = EconomyLedger(
            state: EconomyState(eligibilityStart: boundary),
            repository: repository,
            scheduleCheckpoint: { _, _ in }
        )
        let interval = DateInterval(start: boundary, duration: 10)

        #expect(
            try await ledger.reconcile(
                StepTotal(
                    count: 0,
                    interval: interval,
                    observedAt: interval.end
                )
            ) == 0
        )
        #expect(ledger.state.hasReadableStepData)
        #expect(
            await repository.load()?.state.hasReadableStepData == true
        )
        #expect(ledger.state.availableTokens == 0)
    }

    @Test("Live checkpoint deadline persists dirty spending without sleeping")
    @MainActor
    func manualCheckpointDeadline() async throws {
        let repository = InMemoryLedgerRepository()
        let clock = ManualCheckpointClock()
        let ledger = EconomyLedger(
            state: EconomyState(
                eligibilityStart: .distantPast,
                lifetimeStepsCredited: 3
            ),
            repository: repository,
            scheduleCheckpoint: { delay, operation in
                clock.schedule(after: delay, operation: operation)
            }
        )

        #expect(EconomyLedger.spendCheckpointDelay < .seconds(1))
        _ = ledger.commitMovement(distance: 50)

        let deadline = try #require(clock.nextDeadline)
        #expect(deadline == EconomyLedger.spendCheckpointDelay)
        #expect(await repository.load() == nil)
        #expect(ledger.state.lifetimeTokensSpent == 1)
        #expect(abs(ledger.state.movementRemainder - 6.8) < 0.000_001)

        await clock.fireNext()

        let persisted = try #require(await repository.load())
        #expect(persisted.state == ledger.state)
        let reloaded = try await EconomyLedger.load(
            repository: repository,
            eligibilityStart: .now
        )
        #expect(reloaded.state == ledger.state)
    }
}

@MainActor
private final class ManualCheckpointClock {
    private struct ScheduledCheckpoint {
        let deadline: Duration
        let operation: @MainActor @Sendable () async -> Void
    }

    private(set) var now = Duration.zero
    private var scheduledCheckpoint: ScheduledCheckpoint?

    var nextDeadline: Duration? {
        scheduledCheckpoint?.deadline
    }

    func schedule(
        after delay: Duration,
        operation: @escaping @MainActor @Sendable () async -> Void
    ) {
        scheduledCheckpoint = ScheduledCheckpoint(
            deadline: now + delay,
            operation: operation
        )
    }

    func fireNext() async {
        guard let scheduledCheckpoint else { return }
        self.scheduledCheckpoint = nil
        now = scheduledCheckpoint.deadline
        await scheduledCheckpoint.operation()
    }
}

actor RecordingLedgerRepository: LedgerRepository {
    var records: [LedgerRecord] = []
    func load() async throws -> LedgerRecord? { records.last }
    func save(_ record: LedgerRecord) async throws { records.append(record) }
    func resetCorruptState(to baseline: LedgerRecord) async throws { records = [baseline] }
}
