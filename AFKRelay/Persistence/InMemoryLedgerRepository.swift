import Foundation

actor InMemoryLedgerRepository: LedgerRepository {
    private var record: LedgerRecord?
    private var saveError: LedgerPersistenceError?

    init(record: LedgerRecord? = nil) {
        self.record = record
    }

    func load() -> LedgerRecord? {
        record
    }

    func save(_ proposed: LedgerRecord) throws {
        if let saveError {
            throw saveError
        }
        if let record, proposed.generation <= record.generation {
            throw GenerationStoreError.staleGeneration(
                current: record.generation,
                proposed: proposed.generation
            )
        }
        record = proposed
    }

    func resetCorruptState(to baseline: LedgerRecord) {
        record = baseline
        saveError = nil
    }

    func setSaveError(_ error: LedgerPersistenceError?) {
        saveError = error
    }
}
