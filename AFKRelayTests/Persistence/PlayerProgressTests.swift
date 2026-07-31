import Foundation
import Testing
@testable import AFKRelay

@Suite("Player progress")
struct PlayerProgressTests {
    @Test("Run records update independent personal bests without rewards")
    func recordsPersonalBests() {
        var progress = PlayerProgressState(
            bestSurvivalDuration: 30,
            bestFriendlyFireDefeats: 3,
            completedRunCount: 4
        )
        let update = progress.record(
            LocalRunRecord(
                survivalDuration: 45,
                friendlyFireDefeats: 2,
                tokensSpent: 99,
                endedAt: .now
            )
        )

        #expect(update.isNewSurvivalBest)
        #expect(!update.isNewFriendlyFireBest)
        #expect(progress.bestSurvivalDuration == 45)
        #expect(progress.bestFriendlyFireDefeats == 3)
        #expect(progress.completedRunCount == 5)
    }

    @Test("Tutorial completion persists separately from economy")
    func tutorialCompletion() async throws {
        let repository = InMemoryPlayerProgressRepository()
        var progress = await repository.load()
        progress.markTutorialCompleted()
        try await repository.save(progress)

        #expect(await repository.load().tutorialCompleted)
    }
}

@Suite("Player progress persistence queue")
@MainActor
struct PlayerProgressPersistenceQueueTests {
    @Test("Flush awaits the latest queued snapshot")
    func flushesPendingSnapshot() async throws {
        let repository = ControlledPlayerProgressRepository()
        let queue = PlayerProgressPersistenceQueue(repository: repository)
        let state = PlayerProgressState(tutorialCompleted: true)

        queue.enqueue(state)
        try await queue.flush()

        #expect(await repository.savedStates == [state])
    }

    @Test("Snapshots save in causal order")
    func serializesSnapshots() async throws {
        let repository = ControlledPlayerProgressRepository(
            blockFirstSave: true
        )
        let queue = PlayerProgressPersistenceQueue(repository: repository)
        let tutorial = PlayerProgressState(tutorialCompleted: true)
        let runRecord = PlayerProgressState(
            tutorialCompleted: true,
            bestSurvivalDuration: 42,
            bestFriendlyFireDefeats: 2,
            completedRunCount: 1
        )

        queue.enqueue(tutorial)
        await repository.waitUntilFirstSaveStarts()
        queue.enqueue(runRecord)
        await repository.releaseFirstSave()
        try await queue.flush()

        #expect(await repository.attemptedStates == [tutorial, runRecord])
        #expect(await repository.savedStates == [tutorial, runRecord])
    }

    @Test("A newer complete snapshot recovers after an earlier save failure")
    func newerSnapshotRecovers() async throws {
        let repository = ControlledPlayerProgressRepository(
            failFirstSave: true
        )
        let failures = ProgressFailureRecorder()
        let queue = PlayerProgressPersistenceQueue(
            repository: repository,
            failureHandler: { [weak failures] _ in
                failures?.record()
            }
        )
        let tutorial = PlayerProgressState(tutorialCompleted: true)
        let runRecord = PlayerProgressState(
            tutorialCompleted: true,
            bestSurvivalDuration: 18,
            bestFriendlyFireDefeats: 1,
            completedRunCount: 1
        )

        queue.enqueue(tutorial)
        queue.enqueue(runRecord)
        try await queue.flush()

        #expect(await repository.attemptedStates == [tutorial, runRecord])
        #expect(await repository.savedStates == [runRecord])
        #expect(failures.count == 1)
    }
}

@MainActor
private final class ProgressFailureRecorder {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

nonisolated private enum ControlledProgressRepositoryError: Error, Sendable {
    case failedSave
}

private actor ControlledPlayerProgressRepository: PlayerProgressRepository {
    private let blockFirstSave: Bool
    private let failFirstSave: Bool
    private var firstSaveStarted = false
    private var firstSaveStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstSaveRelease: CheckedContinuation<Void, Never>?
    private(set) var attemptedStates: [PlayerProgressState] = []
    private(set) var savedStates: [PlayerProgressState] = []

    init(
        blockFirstSave: Bool = false,
        failFirstSave: Bool = false
    ) {
        self.blockFirstSave = blockFirstSave
        self.failFirstSave = failFirstSave
    }

    func load() -> PlayerProgressState {
        savedStates.last ?? PlayerProgressState()
    }

    func save(_ state: PlayerProgressState) async throws {
        let isFirstSave = attemptedStates.isEmpty
        attemptedStates.append(state)

        if isFirstSave {
            firstSaveStarted = true
            let waiters = firstSaveStartWaiters
            firstSaveStartWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }

        if isFirstSave, blockFirstSave {
            await withCheckedContinuation { continuation in
                firstSaveRelease = continuation
            }
        }

        if isFirstSave, failFirstSave {
            throw ControlledProgressRepositoryError.failedSave
        }

        savedStates.append(state)
    }

    func waitUntilFirstSaveStarts() async {
        if firstSaveStarted {
            return
        }
        await withCheckedContinuation { continuation in
            firstSaveStartWaiters.append(continuation)
        }
    }

    func releaseFirstSave() {
        firstSaveRelease?.resume()
        firstSaveRelease = nil
    }
}
