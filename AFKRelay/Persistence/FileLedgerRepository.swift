import Foundation
import OSLog

nonisolated enum LedgerPersistenceError: Error, Equatable, Sendable {
    case corruptUnrecoverable
    case invalidState
    case saveFailed
}

actor FileLedgerRepository: LedgerRepository {
    private static var logger: Logger {
        Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "AFKRelay",
            category: "MovementBankPersistence"
        )
    }

    private let store: AtomicGenerationFileStore<EconomyState>

    init(directory: URL) {
        store = AtomicGenerationFileStore(
            directory: directory,
            basename: "economy-ledger-v1",
            validate: Self.isValid
        )
    }

    func load() async throws -> LedgerRecord? {
        switch await store.load() {
        case .absentFirstLaunch:
            return nil
        case let .loaded(state, generation, _):
            return LedgerRecord(generation: generation, state: state)
        case .corruptUnrecoverable:
            throw LedgerPersistenceError.corruptUnrecoverable
        }
    }

    func save(_ record: LedgerRecord) async throws {
        guard Self.isValid(record.state) else {
            Self.logger.error(
                "Rejected an invalid movement-bank state before persistence."
            )
            throw LedgerPersistenceError.invalidState
        }

        do {
            try await store.save(record.state, generation: record.generation)
        } catch {
            throw LedgerPersistenceError.saveFailed
        }
    }

    func resetCorruptState(to baseline: LedgerRecord) async throws {
        guard Self.isZeroCreditBaseline(baseline.state) else {
            throw LedgerPersistenceError.invalidState
        }

        do {
            try await store.replaceCorruptState(
                with: baseline.state,
                generation: baseline.generation
            )
        } catch {
            throw LedgerPersistenceError.saveFailed
        }
    }

    nonisolated private static func isValid(_ state: EconomyState) -> Bool {
        state.schemaVersion == EconomyState.currentSchemaVersion
            && state.observedStepHighWater >= 0
            && state.lifetimeStepsCredited >= 0
            && state.lifetimeStepsCredited == state.observedStepHighWater
            && (
                state.hasReadableStepData
                    || state.lifetimeStepsCredited == 0
            )
            && state.lifetimeTokensSpent >= 0
            && state.lifetimeTokensSpent <= state.lifetimeStepsCredited
            && state.movementRemainder.isFinite
            && state.movementRemainder >= 0
            && state.movementRemainder < MVPBalance.v4.movementDistancePerToken
            && (
                state.lifetimeTokensSpent < state.lifetimeStepsCredited
                    || state.movementRemainder == 0
            )
    }

    nonisolated private static func isZeroCreditBaseline(_ state: EconomyState) -> Bool {
        isValid(state)
            && state.observedStepHighWater == 0
            && state.lifetimeStepsCredited == 0
            && state.lifetimeTokensSpent == 0
            && state.movementRemainder == 0
    }
}
