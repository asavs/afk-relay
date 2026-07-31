import Foundation
import OSLog

nonisolated struct PersistedGeneration<Payload: Codable & Sendable>: Codable, Sendable {
    let formatVersion: Int
    let generation: UInt64
    let savedAt: Date
    let payload: Payload
}

nonisolated enum GenerationLoadResult<Payload: Codable & Sendable>: Sendable {
    case absentFirstLaunch
    case loaded(payload: Payload, generation: UInt64, recoveredFromBackup: Bool)
    case corruptUnrecoverable
}

nonisolated enum GenerationStoreError: Error, Equatable, Sendable {
    case invalidPayload
    case staleGeneration(current: UInt64, proposed: UInt64)
    case unableToCreateDirectory
    case unableToEncode
    case unableToWrite
}

/// Stores the newest two validated generations. Every replacement is atomic,
/// protected while the device is locked before first unlock, and excluded from
/// backup because the payload is derived from local HealthKit reconciliation.
actor AtomicGenerationFileStore<Payload: Codable & Sendable> {
    private static var logger: Logger {
        Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "AFKRelay",
            category: "MovementBankPersistence"
        )
    }

    private let currentURL: URL
    private let previousURL: URL
    private let formatVersion: Int
    private let validate: @Sendable (Payload) -> Bool
    private let fileManager: FileManager

    init(
        directory: URL,
        basename: String,
        formatVersion: Int = 1,
        fileManager: FileManager = .default,
        validate: @escaping @Sendable (Payload) -> Bool
    ) {
        currentURL = directory.appending(path: "\(basename).current.json")
        previousURL = directory.appending(path: "\(basename).previous.json")
        self.formatVersion = formatVersion
        self.fileManager = fileManager
        self.validate = validate
    }

    func load() -> GenerationLoadResult<Payload> {
        let current = readValidatedGeneration(at: currentURL)
        let previous = readValidatedGeneration(at: previousURL)

        if current == nil, previous == nil {
            let hasCurrent = fileManager.fileExists(
                atPath: currentURL.path(percentEncoded: false)
            )
            let hasPrevious = fileManager.fileExists(
                atPath: previousURL.path(percentEncoded: false)
            )
            return hasCurrent || hasPrevious ? .corruptUnrecoverable : .absentFirstLaunch
        }

        switch (current, previous) {
        case let (.some(current), .some(previous)):
            if previous.generation > current.generation {
                return .loaded(
                    payload: previous.payload,
                    generation: previous.generation,
                    recoveredFromBackup: true
                )
            }
            return .loaded(
                payload: current.payload,
                generation: current.generation,
                recoveredFromBackup: false
            )
        case let (.some(current), .none):
            return .loaded(
                payload: current.payload,
                generation: current.generation,
                recoveredFromBackup: false
            )
        case let (.none, .some(previous)):
            return .loaded(
                payload: previous.payload,
                generation: previous.generation,
                recoveredFromBackup: true
            )
        case (.none, .none):
            return .corruptUnrecoverable
        }
    }

    func save(_ payload: Payload, generation: UInt64, savedAt: Date = .now) throws {
        guard validate(payload) else {
            Self.logger.error(
                "Rejected an invalid movement-bank payload before writing generation \(generation, privacy: .public)."
            )
            throw GenerationStoreError.invalidPayload
        }

        try prepareDirectory()

        let current = readValidatedGeneration(at: currentURL)
        let previous = readValidatedGeneration(at: previousURL)
        let newestGeneration = max(current?.generation ?? 0, previous?.generation ?? 0)
        guard generation > newestGeneration else {
            Self.logger.error(
                "Rejected stale movement-bank generation \(generation, privacy: .public); newest stored generation is \(newestGeneration, privacy: .public)."
            )
            throw GenerationStoreError.staleGeneration(
                current: newestGeneration,
                proposed: generation
            )
        }

        if let current {
            try write(current, to: previousURL)
        }

        let next = PersistedGeneration(
            formatVersion: formatVersion,
            generation: generation,
            savedAt: savedAt,
            payload: payload
        )
        try write(next, to: currentURL)
    }

    /// Establishes a readable zero-credit generation after the player confirms
    /// an unrecoverable-corruption reset.
    func replaceCorruptState(
        with baseline: Payload,
        generation: UInt64 = 1,
        savedAt: Date = .now
    ) throws {
        guard validate(baseline) else {
            throw GenerationStoreError.invalidPayload
        }

        try prepareDirectory()
        let envelope = PersistedGeneration(
            formatVersion: formatVersion,
            generation: generation,
            savedAt: savedAt,
            payload: baseline
        )
        try write(envelope, to: previousURL)
        try write(envelope, to: currentURL)
    }

    private func readValidatedGeneration(at url: URL) -> PersistedGeneration<Payload>? {
        guard
            let data = try? Data(contentsOf: url),
            let envelope = try? JSONDecoder().decode(PersistedGeneration<Payload>.self, from: data),
            envelope.formatVersion == formatVersion,
            validate(envelope.payload)
        else {
            return nil
        }

        return envelope
    }

    private func prepareDirectory() throws {
        let directory = currentURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
                ]
            )
            try excludeFromBackup(directory)
        } catch {
            Self.logger.error(
                "Unable to prepare the movement-bank directory: \(String(reflecting: error), privacy: .public)"
            )
            throw GenerationStoreError.unableToCreateDirectory
        }
    }

    private func write(_ envelope: PersistedGeneration<Payload>, to url: URL) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(envelope)
        } catch {
            Self.logger.error(
                "Unable to encode a movement-bank generation: \(String(reflecting: error), privacy: .public)"
            )
            throw GenerationStoreError.unableToEncode
        }

        do {
            try data.write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path(percentEncoded: false)
            )
            try excludeFromBackup(url)
        } catch {
            Self.logger.error(
                "Unable to write \(url.lastPathComponent, privacy: .public): \(String(reflecting: error), privacy: .public)"
            )
            throw GenerationStoreError.unableToWrite
        }
    }

    private func excludeFromBackup(_ url: URL) throws {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try mutableURL.setResourceValues(values)
    }
}
