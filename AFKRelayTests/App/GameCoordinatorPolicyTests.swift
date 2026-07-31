import Foundation
import Testing
@testable import AFKRelay

@Suite("Game coordinator step connection")
@MainActor
struct GameCoordinatorPolicyTests {
    @Test("Unverified saved baseline returns to onboarding without querying")
    func unverifiedBaseline() async throws {
        let boundary = Date(timeIntervalSince1970: 1_800_000_000)
        let reader = CoordinatorStepReader(mode: .count(10))
        let repository = InMemoryLedgerRepository(
            record: LedgerRecord(
                generation: 1,
                state: EconomyState(
                    eligibilityStart: boundary,
                    hasReadableStepData: false
                )
            )
        )
        let coordinator = makeCoordinator(
            reader: reader,
            repository: repository,
            now: boundary.addingTimeInterval(60)
        )

        await coordinator.start()

        #expect(coordinator.screen == .onboarding)
        #expect(coordinator.refreshState == .idle)
        #expect(await reader.queryCount == 0)
        #expect(await repository.load()?.state.eligibilityStart == boundary)
    }

    @Test("No-readable first attempt stays in onboarding and retries access")
    func noReadableRetry() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reader = CoordinatorStepReader(mode: .noReadableData)
        let repository = InMemoryLedgerRepository()
        let coordinator = makeCoordinator(
            reader: reader,
            repository: repository,
            now: now
        )
        await coordinator.start()

        await coordinator.establishStepConnection()
        #expect(coordinator.screen == .onboarding)
        #expect(coordinator.refreshState == .noReadableStepData)
        #expect(await reader.accessRequestCount == 1)
        #expect(await repository.load() == nil)
        await coordinator.establishStepConnection()

        #expect(coordinator.screen == .onboarding)
        #expect(await reader.accessRequestCount == 2)
        #expect(await repository.load() == nil)
    }

    @Test("Failed native request stays retryable and creates no ledger")
    func requestFailure() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reader = CoordinatorStepReader(mode: .requestFailure)
        let repository = InMemoryLedgerRepository()
        let coordinator = makeCoordinator(
            reader: reader,
            repository: repository,
            now: now
        )
        await coordinator.start()

        await coordinator.establishStepConnection()

        #expect(coordinator.screen == .onboarding)
        if case .recoverableFailure = coordinator.refreshState {
            // Expected.
        } else {
            Issue.record("Failed native request must remain retryable")
        }
        #expect(await reader.accessRequestCount == 1)
        #expect(await reader.queryCount == 0)
        #expect(await repository.load() == nil)
    }

    @Test("Validated aggregate is saved before onboarding completes")
    func successfulConnection() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reader = CoordinatorStepReader(mode: .count(321))
        let repository = InMemoryLedgerRepository()
        let coordinator = makeCoordinator(
            reader: reader,
            repository: repository,
            now: now
        )
        await coordinator.start()

        await coordinator.establishStepConnection()

        let record = try #require(await repository.load())
        var expectedCalendar = Calendar(identifier: .gregorian)
        expectedCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(coordinator.screen == .home)
        #expect(coordinator.availableTokens == 321)
        #expect(record.state.hasReadableStepData)
        #expect(record.state.lifetimeStepsCredited == 321)
        #expect(record.state.observedStepHighWater == 321)
        #expect(
            record.state.eligibilityStart
                == expectedCalendar.startOfDay(for: now)
        )
        #expect(await reader.accessRequestCount == 1)
    }

    @Test("Persistence retry requests access and queries again before home")
    func persistenceRetry() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let reader = CoordinatorStepReader(mode: .count(45))
        let repository = InMemoryLedgerRepository()
        await repository.setSaveError(.saveFailed)
        let coordinator = makeCoordinator(
            reader: reader,
            repository: repository,
            now: now
        )
        await coordinator.start()

        await coordinator.establishStepConnection()
        #expect(coordinator.screen == .onboarding)
        if case .persistenceBlocked = coordinator.refreshState {
            // Expected.
        } else {
            Issue.record("Failed first commit must block persistence")
        }
        #expect(await reader.accessRequestCount == 1)
        #expect(await reader.queryCount == 1)

        await repository.setSaveError(nil)
        await coordinator.establishStepConnection()

        #expect(coordinator.screen == .home)
        #expect(coordinator.availableTokens == 45)
        #expect(await reader.accessRequestCount == 2)
        #expect(await reader.queryCount == 2)
        #expect(await repository.load()?.state.hasReadableStepData == true)
    }

    @Test("Onboarding retry enters home only with readable aggregate evidence")
    func onboardingRetry() {
        #expect(
            GameCoordinator.screenAfterSuccessfulPersistenceRetry(
                currentScreen: .onboarding,
                hasActiveRun: false,
                hasReadableStepData: true
            ) == .home
        )
        #expect(
            GameCoordinator.screenAfterSuccessfulPersistenceRetry(
                currentScreen: .onboarding,
                hasActiveRun: false,
                hasReadableStepData: false
            ) == .onboarding
        )
    }

    @Test("Run retry preserves the paused arena")
    func pausedRunRetry() {
        #expect(
            GameCoordinator.screenAfterSuccessfulPersistenceRetry(
                currentScreen: .paused,
                hasActiveRun: true,
                hasReadableStepData: true
            ) == .paused
        )
    }

    private func makeCoordinator(
        reader: CoordinatorStepReader,
        repository: InMemoryLedgerRepository,
        now: Date
    ) -> GameCoordinator {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return GameCoordinator(
            composition: AppComposition(
                stepReader: reader,
                ledgerRepository: repository,
                progressRepository: InMemoryPlayerProgressRepository(),
                presentationCatalog: DiagnosticCatalog(),
                calendar: calendar,
                now: { now }
            )
        )
    }
}

private actor CoordinatorStepReader: StepTotalReading {
    enum Mode: Sendable {
        case count(Int64)
        case noReadableData
        case requestFailure
    }

    let mode: Mode
    private(set) var accessRequestCount = 0
    private(set) var queryCount = 0

    init(mode: Mode) {
        self.mode = mode
    }

    func requestAccess() throws {
        accessRequestCount += 1
        if case .requestFailure = mode {
            throw CoordinatorStepReaderError.requestFailed
        }
    }

    func cumulativeSteps(in interval: DateInterval) throws -> StepTotal {
        queryCount += 1
        switch mode {
        case let .count(count):
            return StepTotal(
                count: count,
                interval: interval,
                observedAt: interval.end
            )
        case .noReadableData:
            throw HealthKitStepReaderError.noReadableStepData
        case .requestFailure:
            throw CoordinatorStepReaderError.requestFailed
        }
    }
}

private enum CoordinatorStepReaderError: Error {
    case requestFailed
}
