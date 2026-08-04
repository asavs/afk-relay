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
    var balance: MVPBalance = .v4
    var initialDiagnosticsOptions: DiagnosticsOptions = .disabled
    var audioPreferencesStore = AudioPreferencesStore()
    /// Where a first connection's eligibility window opens. A seam rather
    /// than a direct call so a test can open the window at the current
    /// instant, making it empty by construction — the condition the ordinary
    /// morning case hits and a device with step history can never reproduce
    /// on demand.
    var eligibilityBoundary: @MainActor @Sendable (Date, Calendar) -> Date = {
        now, calendar in
        StepEligibilityPolicy.firstConnectionBoundary(
            now: now,
            calendar: calendar
        )
    }

    static func current() -> AppComposition {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing-empty-window") {
            return uiTestingLiveHealthEmptyWindow()
        }
        if arguments.contains("--ui-testing-live-health") {
            return uiTestingLiveHealth()
        }
        if arguments.contains("--ui-testing") {
            if arguments.contains("--ui-testing-perf-arena") {
                return uiTestingPerfArena()
            }
            return uiTesting(steps: seededStepArgument() ?? 12_000)
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
    static func uiTesting(steps: Int64 = 12_000) -> AppComposition {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        return AppComposition(
            stepReader: FixedStepTotalReader(count: steps, now: now),
            ledgerRepository: InMemoryLedgerRepository(),
            progressRepository: InMemoryPlayerProgressRepository(),
            presentationCatalog: DiagnosticCatalog(),
            calendar: Calendar(identifier: .gregorian),
            now: { now }
        )
    }

    /// Live HealthKit against disposable storage: the genuine permission and
    /// first-connection flow can run from scratch on every launch without
    /// ever touching the real player container.
    static func uiTestingLiveHealth() -> AppComposition {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "AFKRelayUITests-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        return AppComposition(
            stepReader: HealthKitStepReader(now: { .now }),
            ledgerRepository: FileLedgerRepository(directory: directory),
            progressRepository: FilePlayerProgressRepository(directory: directory),
            presentationCatalog: DiagnosticCatalog(),
            calendar: .autoupdatingCurrent,
            now: { .now }
        )
    }

    /// Live HealthKit with the eligibility window opened at the instant of
    /// connection, so it is empty however much the player has walked today.
    ///
    /// This reproduces on demand what only happens naturally before the first
    /// steps of a day: the window holds nothing while the store holds plenty.
    /// The app must read that as a zero rather than as an unreadable store,
    /// and a device with normal step history can never show that any other
    /// way. Only the boundary moves — the reader, the store, and the
    /// reconciliation are the real ones.
    static func uiTestingLiveHealthEmptyWindow() -> AppComposition {
        var composition = uiTestingLiveHealth()
        composition.eligibilityBoundary = { now, _ in now }
        return composition
    }

    /// A saturated arena for instrumented measurement: completed tutorial,
    /// seeded wallet, rapid spawning to the enemy cap, enough player health
    /// to survive the measurement window, and every diagnostics layer on.
    static func uiTestingPerfArena() -> AppComposition {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let seededSteps: Int64 = 1_000_000
        let state = EconomyState(
            eligibilityStart: now,
            observedStepHighWater: seededSteps,
            lifetimeStepsCredited: seededSteps,
            hasReadableStepData: true
        )
        return AppComposition(
            stepReader: FixedStepTotalReader(count: seededSteps, now: now),
            ledgerRepository: InMemoryLedgerRepository(
                record: LedgerRecord(generation: 1, state: state)
            ),
            progressRepository: InMemoryPlayerProgressRepository(
                state: PlayerProgressState(tutorialCompleted: true)
            ),
            presentationCatalog: DiagnosticCatalog(),
            calendar: Calendar(identifier: .gregorian),
            now: { now },
            balance: perfArenaBalance,
            initialDiagnosticsOptions: .inspection
        )
    }

    /// `MVPBalance.v4` with pressure reached quickly and a player durable
    /// enough to keep the swarm rendering for the whole measurement window.
    /// This is a measurement harness, not a gameplay configuration.
    private static let perfArenaBalance = MVPBalance(
        arenaSize: .init(x: 640, y: 1400),
        playerRadius: 36,
        playerSpeed: 240,
        playerHitPoints: 2_000,
        movementDistancePerToken: 43.2,
        enemyRadius: 34,
        enemySpeed: 90,
        tutorialEnemySpeed: 75,
        enemyHitPoints: 2,
        sweepTriggerDistance: 200,
        sweepReach: 190,
        sweepArcDegrees: 120,
        sweepBladeDegrees: 28,
        sweepTelegraphDuration: 1,
        sweepActiveDuration: 0.45,
        sweepRecoveryDuration: 0.75,
        sweepDamage: 1,
        spawnInitialInterval: 0.5,
        spawnMinimumInterval: 0.5,
        spawnRampDuration: 1,
        enemyCap: 20
    )

    private static func seededStepArgument() -> Int64? {
        for argument in ProcessInfo.processInfo.arguments {
            if let value = argument.wholeMatch(
                of: #/--ui-testing-steps=(\d+)/#
            )?.1 {
                return Int64(value)
            }
        }
        return nil
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
