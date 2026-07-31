import Foundation

nonisolated struct StepTotal: Equatable, Sendable {
    let count: Int64; let interval: DateInterval; let observedAt: Date
    init(count: Int64, interval: DateInterval, observedAt: Date) {
        self.count = count
        self.interval = interval
        self.observedAt = observedAt
    }
}
nonisolated protocol StepTotalReading: Sendable { func requestAccess() async throws; func cumulativeSteps(in interval: DateInterval) async throws -> StepTotal }

nonisolated struct EconomyState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var eligibilityStart: Date
    var observedStepHighWater: Int64
    var lifetimeStepsCredited: Int64
    var lifetimeTokensSpent: Int64
    var movementRemainder: Double
    /// Evidence that HealthKit returned a validated aggregate. This does not
    /// claim knowledge of the user's private read-authorization choice.
    var hasReadableStepData: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        eligibilityStart: Date,
        observedStepHighWater: Int64 = 0,
        lifetimeStepsCredited: Int64 = 0,
        lifetimeTokensSpent: Int64 = 0,
        movementRemainder: Double = 0,
        hasReadableStepData: Bool? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.eligibilityStart = eligibilityStart
        let credited = max(
            max(0, observedStepHighWater),
            max(0, lifetimeStepsCredited)
        )
        self.observedStepHighWater = credited
        self.lifetimeStepsCredited = credited
        self.lifetimeTokensSpent = min(max(0, lifetimeTokensSpent), credited)
        self.movementRemainder = self.lifetimeTokensSpent < credited
            ? max(0, movementRemainder)
            : 0
        self.hasReadableStepData = hasReadableStepData ?? (credited > 0)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSchemaVersion = try container.decode(
            Int.self,
            forKey: .schemaVersion
        )
        let eligibilityStart = try container.decode(
            Date.self,
            forKey: .eligibilityStart
        )
        let observedStepHighWater = try container.decode(
            Int64.self,
            forKey: .observedStepHighWater
        )
        let lifetimeStepsCredited = try container.decode(
            Int64.self,
            forKey: .lifetimeStepsCredited
        )
        let lifetimeTokensSpent = try container.decode(
            Int64.self,
            forKey: .lifetimeTokensSpent
        )
        let movementRemainder = try container.decode(
            Double.self,
            forKey: .movementRemainder
        )

        switch storedSchemaVersion {
        case 1:
            // v1 saved the eligibility boundary before asking HealthKit for
            // access, but had no explicit onboarding-completion evidence.
            // Positive credit proves a validated aggregate was once readable;
            // a zero baseline must safely revisit onboarding.
            self.init(
                eligibilityStart: eligibilityStart,
                observedStepHighWater: observedStepHighWater,
                lifetimeStepsCredited: lifetimeStepsCredited,
                lifetimeTokensSpent: lifetimeTokensSpent,
                movementRemainder: movementRemainder,
                hasReadableStepData: max(
                    observedStepHighWater,
                    lifetimeStepsCredited
                ) > 0
            )
        case Self.currentSchemaVersion:
            self.init(
                eligibilityStart: eligibilityStart,
                observedStepHighWater: observedStepHighWater,
                lifetimeStepsCredited: lifetimeStepsCredited,
                lifetimeTokensSpent: lifetimeTokensSpent,
                movementRemainder: movementRemainder,
                hasReadableStepData: try container.decode(
                    Bool.self,
                    forKey: .hasReadableStepData
                )
            )
        default:
            self.init(
                schemaVersion: storedSchemaVersion,
                eligibilityStart: eligibilityStart,
                observedStepHighWater: observedStepHighWater,
                lifetimeStepsCredited: lifetimeStepsCredited,
                lifetimeTokensSpent: lifetimeTokensSpent,
                movementRemainder: movementRemainder,
                hasReadableStepData: false
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(eligibilityStart, forKey: .eligibilityStart)
        try container.encode(
            observedStepHighWater,
            forKey: .observedStepHighWater
        )
        try container.encode(
            lifetimeStepsCredited,
            forKey: .lifetimeStepsCredited
        )
        try container.encode(
            lifetimeTokensSpent,
            forKey: .lifetimeTokensSpent
        )
        try container.encode(movementRemainder, forKey: .movementRemainder)
        try container.encode(
            hasReadableStepData,
            forKey: .hasReadableStepData
        )
    }

    var availableTokens: Int64 {
        max(0, lifetimeStepsCredited - lifetimeTokensSpent)
    }

    mutating func reconcile(observedSteps: Int64) -> Int64 {
        let observed = max(0, observedSteps)
        hasReadableStepData = true
        // Health totals may revise down. Credit only the net growth beyond the
        // prior high water; preserve previously minted credits and spending.
        guard observed > observedStepHighWater else { return 0 }
        let credit = observed - observedStepHighWater
        observedStepHighWater = observed
        // Health high-water reconciliation remains the sole minting source.
        lifetimeStepsCredited = observed
        return credit
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case eligibilityStart
        case observedStepHighWater
        case lifetimeStepsCredited
        case lifetimeTokensSpent
        case movementRemainder
        case hasReadableStepData
    }
}

nonisolated struct MovementReservation: Equatable, Sendable { let requestedDistance: Double; let affordableDistance: Double; let tokensReserved: Int64 }
nonisolated enum MovementCostPolicy {
    static func reserve(distance: Double, state: EconomyState, balance: MVPBalance = .v1) -> MovementReservation {
        let requested = max(0, distance)
        // Remainder is already travelled-but-not-yet-charged distance, not a
        // credit. It consumes capacity in the token currently being earned.
        let capacity = max(0, Double(state.availableTokens) * balance.movementDistancePerToken - state.movementRemainder)
        let affordable = min(requested, capacity)
        let tokens = Int64(
            ((state.movementRemainder + affordable) / balance.movementDistancePerToken)
                .rounded(.down)
        )
        return .init(requestedDistance: requested, affordableDistance: affordable, tokensReserved: min(tokens, state.availableTokens))
    }
    @discardableResult static func commit(distance: Double, state: inout EconomyState, balance: MVPBalance = .v1) -> Double {
        let allowed = reserve(distance: distance, state: state, balance: balance).affordableDistance
        let total = state.movementRemainder + allowed
        let spend = min(state.availableTokens, Int64((total / balance.movementDistancePerToken).rounded(.down)))
        state.lifetimeTokensSpent += spend
        state.movementRemainder = total - Double(spend) * balance.movementDistancePerToken
        return allowed
    }
}

nonisolated struct LedgerRecord: Codable, Equatable, Sendable { let generation: UInt64; let state: EconomyState; init(generation: UInt64, state: EconomyState) { self.generation = generation; self.state = state } }
nonisolated protocol LedgerRepository: Sendable { func load() async throws -> LedgerRecord?; func save(_ record: LedgerRecord) async throws; func resetCorruptState(to baseline: LedgerRecord) async throws }
nonisolated enum EconomyLedgerError: Error, Equatable, Sendable { case invalidAggregate; case persistenceFailed }

@MainActor final class EconomyLedger {
    typealias CheckpointScheduler = @MainActor @Sendable (
        _ delay: Duration,
        _ operation: @escaping @MainActor @Sendable () async -> Void
    ) -> Void
    nonisolated static let spendCheckpointDelay = Duration.milliseconds(500)

    private let repository: any LedgerRepository
    private let scheduleCheckpoint: CheckpointScheduler
    private(set) var state: EconomyState
    private(set) var persistenceFailure = false
    private var generation: UInt64
    private var spendRevision: UInt64 = 0
    private var persistedSpendRevision: UInt64 = 0
    private var checkpointScheduled = false
    private var checkpointFlight: CheckpointFlight?
    private var nextCheckpointFlightID: UInt64 = 0
    private var saveTail: Task<Void, any Error>?
    private var pendingReconciliation: PendingReconciliation?

    init(
        state: EconomyState,
        generation: UInt64 = 0,
        repository: any LedgerRepository,
        scheduleCheckpoint: @escaping CheckpointScheduler = {
            delay, operation in
            EconomyLedger.liveCheckpointScheduler(
                after: delay,
                operation
            )
        }
    ) {
        self.state = state
        self.generation = generation
        self.repository = repository
        self.scheduleCheckpoint = scheduleCheckpoint
    }

    static func load(repository: any LedgerRepository, eligibilityStart: Date) async throws -> EconomyLedger {
        let record = try await repository.load()
        return EconomyLedger(
            state: record?.state ?? EconomyState(eligibilityStart: eligibilityStart),
            generation: record?.generation ?? 0,
            repository: repository
        )
    }

    func reconcile(_ total: StepTotal) async throws -> Int64 {
        while let pendingReconciliation {
            try await pendingReconciliation.task.value
            await Task.yield()
        }

        guard
            total.count >= 0,
            total.interval.start == state.eligibilityStart,
            total.interval.end >= total.interval.start,
            total.observedAt >= total.interval.end
        else {
            throw EconomyLedgerError.invalidAggregate
        }

        var candidate = state
        let credit = candidate.reconcile(observedSteps: total.count)
        guard candidate != state else { return 0 }
        // Persist a candidate first. Main-actor reentrancy can permit movement
        // while this awaits; applying only the delta afterward preserves it.
        let task = makeSaveTask(candidate)
        pendingReconciliation = PendingReconciliation(
            candidate: candidate,
            credit: credit,
            task: task
        )
        do {
            try await task.value
            state.observedStepHighWater = max(
                state.observedStepHighWater,
                candidate.observedStepHighWater
            )
            state.lifetimeStepsCredited += credit
            state.hasReadableStepData = candidate.hasReadableStepData
            pendingReconciliation = nil
            clearPersistenceFailure()
            return credit
        } catch {
            pendingReconciliation = nil
            recordPersistenceFailure()
            throw EconomyLedgerError.persistenceFailed
        }
    }
    func commitMovement(distance: Double) -> Double {
        guard !persistenceFailure else { return 0 }
        let result = MovementCostPolicy.commit(distance: distance, state: &state)
        if result > 0 {
            spendRevision &+= 1
            scheduleDirtyCheckpointIfNeeded()
        }
        return result
    }

    func checkpoint() async throws {
        let targetRevision = spendRevision
        guard persistedSpendRevision < targetRevision else { return }

        while persistedSpendRevision < targetRevision {
            if let checkpointFlight {
                do {
                    try await checkpointFlight.task.value
                    if self.checkpointFlight?.id == checkpointFlight.id {
                        self.checkpointFlight = nil
                    }
                } catch {
                    if self.checkpointFlight?.id == checkpointFlight.id {
                        self.checkpointFlight = nil
                    }
                    recordPersistenceFailure()
                    throw EconomyLedgerError.persistenceFailed
                }
                continue
            }

            nextCheckpointFlightID &+= 1
            let flightID = nextCheckpointFlightID
            let task = Task { @MainActor [self] in
                try await performCheckpoint()
            }
            checkpointFlight = CheckpointFlight(id: flightID, task: task)

            do {
                try await task.value
                if checkpointFlight?.id == flightID {
                    checkpointFlight = nil
                }
            } catch {
                if checkpointFlight?.id == flightID {
                    checkpointFlight = nil
                }
                recordPersistenceFailure()
                throw EconomyLedgerError.persistenceFailed
            }
        }
    }

    private func performCheckpoint() async throws {
        let revisionBeingSaved = spendRevision
        var snapshot = state
        if let pendingReconciliation {
            do {
                try await pendingReconciliation.task.value
            } catch {
                recordPersistenceFailure()
                throw EconomyLedgerError.persistenceFailed
            }
            snapshot.observedStepHighWater = max(
                snapshot.observedStepHighWater,
                pendingReconciliation.candidate.observedStepHighWater
            )
            snapshot.lifetimeStepsCredited += pendingReconciliation.credit
            snapshot.hasReadableStepData =
                pendingReconciliation.candidate.hasReadableStepData
        }
        try await save(snapshot)
        persistedSpendRevision = max(persistedSpendRevision, revisionBeingSaved)
    }

    func flush() async throws {
        if persistenceFailure {
            try await retryPersistence()
        } else {
            try await checkpoint()
        }
    }

    func retryPersistence() async throws {
        try await save()
        persistedSpendRevision = spendRevision
    }

    func resetCorruptState(eligibilityStart: Date) async throws {
        let baseline = EconomyState(eligibilityStart: eligibilityStart)
        let record = LedgerRecord(generation: 1, state: baseline)
        do {
            try await repository.resetCorruptState(to: record)
            state = baseline
            generation = 1
            spendRevision = 0
            persistedSpendRevision = 0
            checkpointScheduled = false
            checkpointFlight = nil
            saveTail = nil
            pendingReconciliation = nil
            clearPersistenceFailure()
        } catch {
            recordPersistenceFailure()
            throw EconomyLedgerError.persistenceFailed
        }
    }

    private func save(_ value: EconomyState? = nil) async throws {
        let task = makeSaveTask(value ?? state)
        do {
            try await task.value
            clearPersistenceFailure()
        } catch {
            recordPersistenceFailure()
            throw EconomyLedgerError.persistenceFailed
        }
    }

    private func clearPersistenceFailure() {
        persistenceFailure = false
    }

    private func recordPersistenceFailure() {
        persistenceFailure = true
    }

    private func makeSaveTask(_ value: EconomyState) -> Task<Void, any Error> {
        guard generation < .max else {
            return Task {
                throw EconomyLedgerError.persistenceFailed
            }
        }

        // Reserve before suspension and chain repository writes so refresh and
        // spending generations cannot arrive out of order.
        let next = generation + 1
        generation = next
        let previous = saveTail
        let repository = repository
        let record = LedgerRecord(generation: next, state: value)
        let task = Task {
            if let previous {
                _ = try? await previous.value
            }
            try await repository.save(record)
        }
        saveTail = task
        return task
    }

    private func scheduleDirtyCheckpointIfNeeded() {
        guard persistedSpendRevision != spendRevision, !checkpointScheduled else {
            return
        }
        checkpointScheduled = true
        scheduleCheckpoint(Self.spendCheckpointDelay) { [weak self] in
            await self?.runScheduledCheckpoint()
        }
    }

    private func runScheduledCheckpoint() async {
        checkpointScheduled = false
        do {
            try await checkpoint()
            scheduleDirtyCheckpointIfNeeded()
        } catch {
            // `save` exposes the failure flag. Gameplay observes it on the
            // next fixed tick and pauses until an explicit retry succeeds.
        }
    }

    private static func liveCheckpointScheduler(
        after delay: Duration,
        _ operation: @escaping @MainActor @Sendable () async -> Void
    ) {
        Task { @MainActor in
            // This bounds when the checkpoint attempt begins and leaves budget
            // inside the one-second product window. Filesystem completion time
            // is awaited and verified on device; it is not assumed to be
            // arbitrarily bounded by this scheduler.
            try? await Task.sleep(for: delay)
            await operation()
        }
    }

    private struct PendingReconciliation {
        let candidate: EconomyState
        let credit: Int64
        let task: Task<Void, any Error>
    }

    private struct CheckpointFlight {
        let id: UInt64
        let task: Task<Void, any Error>
    }
}
