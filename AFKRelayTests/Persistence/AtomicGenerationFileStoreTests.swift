import Foundation
import Testing
@testable import AFKRelay

@Suite("Atomic generation file store")
struct AtomicGenerationFileStoreTests {
    @Test("Loads the latest generation and recovers the previous generation")
    func backupRecovery() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AtomicGenerationFileStore<FixturePayload>(
            directory: directory,
            basename: "ledger",
            validate: { $0.value >= 0 }
        )

        try await store.save(FixturePayload(value: 10), generation: 1)
        try await store.save(FixturePayload(value: 20), generation: 2)

        switch await store.load() {
        case let .loaded(payload, generation, recovered):
            #expect(payload.value == 20)
            #expect(generation == 2)
            #expect(!recovered)
        default:
            Issue.record("Expected the current generation")
        }

        let currentURL = directory.appending(path: "ledger.current.json")
        try Data("not-json".utf8).write(to: currentURL, options: .atomic)

        switch await store.load() {
        case let .loaded(payload, generation, recovered):
            #expect(payload.value == 10)
            #expect(generation == 1)
            #expect(recovered)
        default:
            Issue.record("Expected recovery from the previous generation")
        }
    }

    @Test("Distinguishes first launch from unrecoverable corruption")
    func absenceAndCorruption() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AtomicGenerationFileStore<FixturePayload>(
            directory: directory,
            basename: "ledger",
            validate: { $0.value >= 0 }
        )

        if case .absentFirstLaunch = await store.load() {
            // Expected.
        } else {
            Issue.record("A missing store must be treated as first launch")
        }

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data("broken".utf8).write(
            to: directory.appending(path: "ledger.current.json"),
            options: .atomic
        )

        if case .corruptUnrecoverable = await store.load() {
            // Expected.
        } else {
            Issue.record("An unreadable existing store must fail closed")
        }
    }

    @Test("Paths with spaces remain writable and corruption is not mistaken for first launch")
    func spacedDirectoryPersistence() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(
            path: "Library/Application Support/AFK Relay",
            directoryHint: .isDirectory
        )
        let store = AtomicGenerationFileStore<FixturePayload>(
            directory: directory,
            basename: "ledger",
            validate: { $0.value >= 0 }
        )

        try await store.save(FixturePayload(value: 10), generation: 1)
        try await store.save(FixturePayload(value: 20), generation: 2)

        switch await store.load() {
        case let .loaded(payload, generation, _):
            #expect(payload.value == 20)
            #expect(generation == 2)
        default:
            Issue.record("Expected the latest generation from a spaced path")
        }

        for name in ["ledger.current.json", "ledger.previous.json"] {
            try Data("broken".utf8).write(
                to: directory.appending(path: name),
                options: .atomic
            )
        }

        if case .corruptUnrecoverable = await store.load() {
            // Expected.
        } else {
            Issue.record("Existing corrupt files must not look like first launch")
        }
    }

    @Test("Explicit corruption reset establishes a readable baseline")
    func explicitReset() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AtomicGenerationFileStore<FixturePayload>(
            directory: directory,
            basename: "ledger",
            validate: { $0.value >= 0 }
        )

        try await store.replaceCorruptState(
            with: FixturePayload(value: 0),
            generation: 1
        )

        switch await store.load() {
        case let .loaded(payload, generation, _):
            #expect(payload.value == 0)
            #expect(generation == 1)
        default:
            Issue.record("The reset baseline must be readable")
        }
    }

    @Test("Ledger reload preserves durable credit, spend, and remainder")
    func ledgerRelaunchRetention() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileLedgerRepository(directory: directory)
        var state = EconomyState(
            eligibilityStart: Date(timeIntervalSince1970: 1_800_000_000),
            lifetimeStepsCredited: 1_000
        )
        _ = MovementCostPolicy.commit(distance: 50, state: &state)
        try await repository.save(LedgerRecord(generation: 1, state: state))

        let restored = try await FileLedgerRepository(directory: directory).load()

        #expect(restored?.generation == 1)
        #expect(restored?.state == state)
    }

    @Test("Impossible schema-v2 economy states are rejected")
    func invalidLedgerMatrix() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileLedgerRepository(directory: directory)
        var mismatchedCredit = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 100
        )
        mismatchedCredit.lifetimeStepsCredited = 0
        var remainderWithoutToken = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 1,
            lifetimeTokensSpent: 1
        )
        remainderWithoutToken.movementRemainder = 2

        for state in [mismatchedCredit, remainderWithoutToken] {
            do {
                try await repository.save(
                    LedgerRecord(generation: 1, state: state)
                )
                Issue.record("Invalid ledger state was persisted")
            } catch {
                #expect(error as? LedgerPersistenceError == .invalidState)
            }
        }
    }

    @Test("Schema-v1 zero baseline migrates as unverified without moving boundary")
    func migrateLegacyZeroBaseline() throws {
        let boundary = Date(timeIntervalSince1970: 1_234_567)
        let legacy = LegacyEconomyStateV1(
            schemaVersion: 1,
            eligibilityStart: boundary,
            observedStepHighWater: 0,
            lifetimeStepsCredited: 0,
            lifetimeTokensSpent: 0,
            movementRemainder: 0
        )

        let migrated = try JSONDecoder().decode(
            EconomyState.self,
            from: JSONEncoder().encode(legacy)
        )

        #expect(migrated.schemaVersion == EconomyState.currentSchemaVersion)
        #expect(migrated.eligibilityStart == boundary)
        #expect(!migrated.hasReadableStepData)
        #expect(migrated.availableTokens == 0)
    }

    @Test("Schema-v1 credited bank migrates as readable without changing values")
    func migrateLegacyCreditedBank() throws {
        let boundary = Date(timeIntervalSince1970: 7_654_321)
        let legacy = LegacyEconomyStateV1(
            schemaVersion: 1,
            eligibilityStart: boundary,
            observedStepHighWater: 500,
            lifetimeStepsCredited: 500,
            lifetimeTokensSpent: 123,
            movementRemainder: 4.5
        )

        let migrated = try JSONDecoder().decode(
            EconomyState.self,
            from: JSONEncoder().encode(legacy)
        )

        #expect(migrated.schemaVersion == EconomyState.currentSchemaVersion)
        #expect(migrated.eligibilityStart == boundary)
        #expect(migrated.observedStepHighWater == 500)
        #expect(migrated.lifetimeStepsCredited == 500)
        #expect(migrated.lifetimeTokensSpent == 123)
        #expect(migrated.movementRemainder == 4.5)
        #expect(migrated.hasReadableStepData)
    }

    @Test("A schema-v1 envelope migrates and saves its next generation in Application Support")
    func migrateLegacyEnvelopeInSpacedDirectory() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(
            path: "Library/Application Support/AFKRelay",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let boundary = Date(timeIntervalSince1970: 1_234_567)
        let legacy = LegacyEconomyStateV1(
            schemaVersion: 1,
            eligibilityStart: boundary,
            observedStepHighWater: 0,
            lifetimeStepsCredited: 0,
            lifetimeTokensSpent: 0,
            movementRemainder: 0
        )
        let envelope = PersistedGeneration(
            formatVersion: 1,
            generation: 7,
            savedAt: boundary,
            payload: legacy
        )
        try JSONEncoder().encode(envelope).write(
            to: directory.appending(path: "economy-ledger-v1.current.json"),
            options: .atomic
        )

        let repository = FileLedgerRepository(directory: directory)
        let migrated = try #require(await repository.load())
        #expect(migrated.generation == 7)
        #expect(migrated.state.eligibilityStart == boundary)
        #expect(!migrated.state.hasReadableStepData)

        var readable = migrated.state
        _ = readable.reconcile(observedSteps: 321)
        try await repository.save(
            LedgerRecord(generation: 8, state: readable)
        )

        let reloaded = try #require(await repository.load())
        #expect(reloaded.generation == 8)
        #expect(reloaded.state.schemaVersion == EconomyState.currentSchemaVersion)
        #expect(reloaded.state.hasReadableStepData)
        #expect(reloaded.state.availableTokens == 321)
    }

    @Test("Saved files are protected and excluded from cloud backup")
    func fileAttributes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AtomicGenerationFileStore<FixturePayload>(
            directory: directory,
            basename: "attributes",
            validate: { $0.value >= 0 }
        )

        try await store.save(FixturePayload(value: 1), generation: 1)

        let currentURL = directory.appending(path: "attributes.current.json")
        let values = try currentURL.resourceValues(
            forKeys: [.isExcludedFromBackupKey]
        )
        let attributes = try FileManager.default.attributesOfItem(
            atPath: currentURL.path(percentEncoded: false)
        )
        #expect(values.isExcludedFromBackup == true)
#if targetEnvironment(simulator)
        // APFS data protection classes are not surfaced by iOS Simulator.
        #expect(attributes[.protectionKey] == nil)
#else
        #expect(
            attributes[.protectionKey] as? FileProtectionType
                == .completeUntilFirstUserAuthentication
        )
#endif
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "AFKRelayTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }
}

private nonisolated struct FixturePayload: Codable, Sendable {
    let value: Int
}

private nonisolated struct LegacyEconomyStateV1: Codable, Sendable {
    let schemaVersion: Int
    let eligibilityStart: Date
    let observedStepHighWater: Int64
    let lifetimeStepsCredited: Int64
    let lifetimeTokensSpent: Int64
    let movementRemainder: Double
}
