import Foundation

nonisolated struct LocalRunRecord: Codable, Equatable, Sendable {
    let survivalDuration: TimeInterval
    let friendlyFireDefeats: Int
    let tokensSpent: Int64
    let endedAt: Date
}

nonisolated struct PlayerProgressUpdate: Equatable, Sendable {
    let state: PlayerProgressState
    let isNewSurvivalBest: Bool
    let isNewFriendlyFireBest: Bool
}

nonisolated struct PlayerProgressState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var tutorialCompleted: Bool
    var bestSurvivalDuration: TimeInterval
    var bestFriendlyFireDefeats: Int
    var completedRunCount: Int

    init(
        schemaVersion: Int = currentSchemaVersion,
        tutorialCompleted: Bool = false,
        bestSurvivalDuration: TimeInterval = 0,
        bestFriendlyFireDefeats: Int = 0,
        completedRunCount: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.tutorialCompleted = tutorialCompleted
        self.bestSurvivalDuration = bestSurvivalDuration
        self.bestFriendlyFireDefeats = bestFriendlyFireDefeats
        self.completedRunCount = completedRunCount
    }

    mutating func markTutorialCompleted() {
        tutorialCompleted = true
    }

    mutating func record(_ run: LocalRunRecord) -> PlayerProgressUpdate {
        let isNewSurvivalBest = run.survivalDuration > bestSurvivalDuration
        let isNewFriendlyFireBest = run.friendlyFireDefeats > bestFriendlyFireDefeats

        bestSurvivalDuration = max(bestSurvivalDuration, run.survivalDuration)
        bestFriendlyFireDefeats = max(bestFriendlyFireDefeats, run.friendlyFireDefeats)
        completedRunCount += 1

        return PlayerProgressUpdate(
            state: self,
            isNewSurvivalBest: isNewSurvivalBest,
            isNewFriendlyFireBest: isNewFriendlyFireBest
        )
    }

    var isValid: Bool {
        schemaVersion == Self.currentSchemaVersion
            && bestSurvivalDuration.isFinite
            && bestSurvivalDuration >= 0
            && bestFriendlyFireDefeats >= 0
            && completedRunCount >= 0
    }
}

nonisolated protocol PlayerProgressRepository: Sendable {
    func load() async throws -> PlayerProgressState
    func save(_ state: PlayerProgressState) async throws
}

nonisolated enum PlayerProgressPersistenceError: Error, Equatable, Sendable {
    case corrupt
    case invalidState
    case saveFailed
}

@MainActor
final class PlayerProgressPersistenceQueue {
    typealias FailureHandler = @MainActor @Sendable (any Error) -> Void

    private let repository: any PlayerProgressRepository
    private var failureHandler: FailureHandler
    private var nextFlightID: UInt64 = 0
    private var tail: SaveFlight?

    init(
        repository: any PlayerProgressRepository,
        failureHandler: @escaping FailureHandler = { _ in }
    ) {
        self.repository = repository
        self.failureHandler = failureHandler
    }

    func setFailureHandler(_ failureHandler: @escaping FailureHandler) {
        self.failureHandler = failureHandler
    }

    @discardableResult
    func enqueue(
        _ state: PlayerProgressState
    ) -> Task<Void, any Error> {
        nextFlightID &+= 1
        let flightID = nextFlightID
        let previous = tail?.task
        let repository = repository
        let failureHandler = failureHandler
        let task = Task { @MainActor in
            if let previous {
                // Preserve causal order, but let a newer complete snapshot
                // recover persistence after an earlier write failure.
                _ = await previous.result
            }

            do {
                try await repository.save(state)
            } catch {
                failureHandler(error)
                throw error
            }
        }
        tail = SaveFlight(id: flightID, task: task)
        return task
    }

    func flush() async throws {
        while let flight = tail {
            do {
                try await flight.task.value
            } catch {
                // A newer queued snapshot includes all earlier progress. Let it
                // recover the chain before reporting the flush as failed.
                guard tail?.id != flight.id else {
                    throw error
                }
            }

            guard tail?.id != flight.id else {
                return
            }
        }
    }

    private struct SaveFlight {
        let id: UInt64
        let task: Task<Void, any Error>
    }
}

actor FilePlayerProgressRepository: PlayerProgressRepository {
    private let store: AtomicGenerationFileStore<PlayerProgressState>
    private var generation: UInt64 = 0

    init(directory: URL) {
        store = AtomicGenerationFileStore(
            directory: directory,
            basename: "player-progress-v1",
            validate: { $0.isValid }
        )
    }

    func load() async throws -> PlayerProgressState {
        switch await store.load() {
        case .absentFirstLaunch:
            generation = 0
            return PlayerProgressState()
        case let .loaded(state, loadedGeneration, _):
            generation = loadedGeneration
            return state
        case .corruptUnrecoverable:
            throw PlayerProgressPersistenceError.corrupt
        }
    }

    func save(_ state: PlayerProgressState) async throws {
        guard state.isValid else {
            throw PlayerProgressPersistenceError.invalidState
        }

        let proposedGeneration = generation + 1
        // Reserve before the actor-reentrant store await so overlapping saves
        // always receive distinct, ordered generations.
        generation = proposedGeneration
        do {
            try await store.save(state, generation: proposedGeneration)
        } catch {
            throw PlayerProgressPersistenceError.saveFailed
        }
    }
}

actor InMemoryPlayerProgressRepository: PlayerProgressRepository {
    private var state: PlayerProgressState

    init(state: PlayerProgressState = PlayerProgressState()) {
        self.state = state
    }

    func load() -> PlayerProgressState {
        state
    }

    func save(_ state: PlayerProgressState) throws {
        guard state.isValid else {
            throw PlayerProgressPersistenceError.invalidState
        }
        self.state = state
    }
}
