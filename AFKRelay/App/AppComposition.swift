import Foundation

/// The sole construction boundary for live, test, and future entitled
/// presentation dependencies. Catalog selection cannot enter the simulation.
@MainActor
struct AppComposition {
    let stepReader: any StepTotalReading
    let ledgerRepository: any LedgerRepository
    let progressRepository: any PlayerProgressRepository
    let presentationCatalog: any ArenaPresentationCatalog
    let calendar: Calendar
    let now: @MainActor @Sendable () -> Date

    static func current() -> AppComposition {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            return uiTesting()
        }
#endif
        return live()
    }

    static func live(
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @MainActor @Sendable () -> Date = { .now }
    ) -> AppComposition {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = applicationSupport
            .appending(path: "AFKRelay", directoryHint: .isDirectory)

        return AppComposition(
            stepReader: HealthKitStepReader(now: now),
            ledgerRepository: FileLedgerRepository(directory: directory),
            progressRepository: FilePlayerProgressRepository(directory: directory),
            presentationCatalog: DiagnosticCatalog(),
            calendar: calendar,
            now: now
        )
    }

#if DEBUG
    static func uiTesting() -> AppComposition {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        return AppComposition(
            stepReader: FixedStepTotalReader(count: 12_000, now: now),
            ledgerRepository: InMemoryLedgerRepository(),
            progressRepository: InMemoryPlayerProgressRepository(),
            presentationCatalog: DiagnosticCatalog(),
            calendar: Calendar(identifier: .gregorian),
            now: { now }
        )
    }
#endif
}

#if DEBUG
@MainActor
private final class FixedStepTotalReader: StepTotalReading {
    private let count: Int64
    private let now: Date

    init(count: Int64, now: Date) {
        self.count = count
        self.now = now
    }

    func requestAccess() async throws {}

    func cumulativeSteps(in interval: DateInterval) async throws -> StepTotal {
        StepTotal(count: count, interval: interval, observedAt: now)
    }
}
#endif
