import Foundation
import Observation
import UIKit

nonisolated enum GameScreen: Equatable, Sendable {
    case loading
    case onboarding
    case home
    case running
    case paused
    case runSummary
    case economyRecovery
}

nonisolated enum GameCoordinatorError: Error, Equatable, Sendable {
    case missingLedger
}

extension GameCoordinator {
    static let interruptedConnectionMessage =
        "Setting up Apple Health was interrupted. Try again."
}

nonisolated enum StepRefreshOutcome: Equatable, Sendable {
    case current
    case noReadableData
    case recoverableFailure
    case persistenceBlocked
    case cancelled
}

@MainActor
@Observable
final class GameCoordinator {
    private(set) var screen = GameScreen.loading
    private(set) var availableTokens: Int64 = 0
    private(set) var playerHealth = MVPBalance.v4.playerHitPoints
    private(set) var survivalDuration: TimeInterval = 0
    private(set) var tokensSpentThisRun: Int64 = 0
    private(set) var friendlyFireDefeatsThisRun = 0
    private(set) var refreshState = WalletRefreshPresentationState.idle
    /// HealthKit's own trailing 30-day daily average; presentation-only
    /// context for the bank gauge, never a minting input.
    private(set) var averageDailySteps: Int64 = 0
    private(set) var runSummary: RunSummaryModel?
    private(set) var progressMessage: String?
    var diagnosticsOptions = DiagnosticsOptions.disabled {
        didSet {
            arenaScene.diagnosticsOptions = diagnosticsOptions
        }
    }

    @ObservationIgnored let arenaScene: ArenaScene
    @ObservationIgnored private let composition: AppComposition
    @ObservationIgnored private let soundPlayer: PresentationSoundPlayer
    @ObservationIgnored private let progressPersistence:
        PlayerProgressPersistenceQueue
    @ObservationIgnored private var economyLedger: EconomyLedger?
    @ObservationIgnored private var refreshService: StepRefreshService?
    @ObservationIgnored private var simulation: ArenaSimulation?
    @ObservationIgnored private var playerProgress = PlayerProgressState()
    @ObservationIgnored private var movementIntent = Vector2.zero
    @ObservationIgnored private var runStartingLifetimeSpend: Int64 = 0
    @ObservationIgnored private var runStartingTokens: Int64 = 1
    @ObservationIgnored private var bootstrapStarted = false
    @ObservationIgnored private var isEstablishingStepConnection = false
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycleFlushTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    init(composition: AppComposition) {
        self.composition = composition
        soundPlayer = PresentationSoundPlayer(
            catalog: composition.presentationCatalog
        )
        progressPersistence = PlayerProgressPersistenceQueue(
            repository: composition.progressRepository
        )
        arenaScene = ArenaScene(catalog: composition.presentationCatalog)
        playerHealth = composition.balance.playerHitPoints
        // Observers do not fire during init; mirror to the scene directly.
        diagnosticsOptions = composition.initialDiagnosticsOptions
        arenaScene.diagnosticsOptions = composition.initialDiagnosticsOptions
        progressPersistence.setFailureHandler { [weak self] _ in
            self?.progressMessage = "Your run history couldn’t be saved to this iPhone."
        }
        arenaScene.fixedStepHandler = { [weak self] duration in
            self?.advanceFixedStep(duration: duration)
        }
    }

    var hudModel: ArenaHUDModel {
        ArenaHUDModel(
            availableTokens: availableTokens,
            runStartingTokens: runStartingTokens,
            playerHealth: playerHealth,
            maximumPlayerHealth: composition.balance.playerHitPoints,
            survivalDuration: survivalDuration,
            tokensSpentThisRun: tokensSpentThisRun,
            refreshState: refreshState
        )
    }

    var diagnosticsHUDModel: ArenaDiagnosticsHUDModel {
        let snapshot = simulation?.snapshot
        let balance = simulation?.balance ?? composition.balance
        let fixedStepHz = 1 / ArenaSimulation.fixedTimeStep
        return ArenaDiagnosticsHUDModel(
            fixedStepHz: Int(fixedStepHz.rounded()),
            renderedFramesPerSecond: arenaScene.renderedFramesPerSecond,
            simulationTick: UInt64(
                max(0, ((snapshot?.elapsed ?? 0) * fixedStepHz).rounded(.down))
            ),
            livingEnemies: snapshot?.enemies.count ?? 0,
            activeAttacks: snapshot?.attacks.filter {
                $0.isActive(balance: balance)
            }.count ?? 0
        )
    }

    var canStartRun: Bool {
        availableTokens > 0 && !isPersistenceBlocked
    }

    func playButtonSound() {
        soundPlayer.play(.buttonPress)
    }

    // Read when a screen is built; records only change across screen
    // transitions, so plain reads of the untracked progress state suffice.
    var bestSurvivalDuration: TimeInterval { playerProgress.bestSurvivalDuration }
    var bestFriendlyFireDefeats: Int { playerProgress.bestFriendlyFireDefeats }
    var hasRunRecords: Bool { playerProgress.completedRunCount > 0 }

    nonisolated static func screenAfterSuccessfulPersistenceRetry(
        currentScreen: GameScreen,
        hasActiveRun: Bool,
        hasReadableStepData: Bool
    ) -> GameScreen {
        if currentScreen == .onboarding,
           !hasActiveRun,
           hasReadableStepData
        {
            return .home
        }
        return currentScreen
    }

    func start() async {
        guard !bootstrapStarted else { return }
        bootstrapStarted = true
        await bootstrap()
    }

    func connectSteps() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            await self?.establishStepConnection()
        }
    }

    func refreshSteps(requestAccess: Bool = false) {
        if !requestAccess,
           economyLedger?.state.hasReadableStepData != true
        {
            connectSteps()
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            _ = await self?.performRefresh(requestAccess: requestAccess)
        }
    }

    func retryPersistenceAndRefresh() {
        if screen == .onboarding {
            connectSteps()
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self, let economyLedger = self.economyLedger else {
                return
            }

            do {
                if economyLedger.persistenceFailure {
                    try await economyLedger.retryPersistence()
                }
                self.publishEconomy()
                _ = await self.performRefresh(requestAccess: false)
                if !self.isPersistenceBlocked {
                    self.screen = Self.screenAfterSuccessfulPersistenceRetry(
                        currentScreen: self.screen,
                        hasActiveRun: self.simulation != nil,
                        hasReadableStepData:
                            economyLedger.state.hasReadableStepData
                    )
                }
            } catch {
                self.blockForPersistenceFailure()
            }
        }
    }

    func startRun() {
        guard canStartRun, let economyLedger else { return }
        movementIntent = .zero
        runStartingLifetimeSpend = economyLedger.state.lifetimeTokensSpent
        runStartingTokens = max(1, economyLedger.state.availableTokens)
        tokensSpentThisRun = 0
        friendlyFireDefeatsThisRun = 0
        survivalDuration = 0
        playerHealth = composition.balance.playerHitPoints
        simulation = ArenaSimulation(
            balance: composition.balance,
            tutorialCompleted: playerProgress.tutorialCompleted
        )
        screen = .running
        arenaScene.setApplicationActive(true)

        if let simulation {
            arenaScene.publish(
                ArenaSnapshotPresentationAdapter.makeSnapshot(
                    from: simulation.snapshot,
                    balance: simulation.balance,
                    renderedFramesPerSecond: arenaScene.renderedFramesPerSecond
                )
            )
        }
    }

    func setMovementIntent(_ intent: MovementIntent) {
        let vector = Vector2(x: intent.x, y: intent.y)
        movementIntent = vector.length > 1 ? vector.normalized : vector
    }

    func pauseRun() {
        guard screen == .running else { return }
        movementIntent = .zero
        screen = .paused
        arenaScene.setApplicationActive(false)
        flushPersistence()
    }

    func resumeRun() {
        guard screen == .paused, !isPersistenceBlocked else { return }
        screen = .running
        arenaScene.setApplicationActive(true)
    }

    func endRun() {
        guard simulation != nil else {
            screen = .home
            return
        }
        completeRun()
    }

    func runAgain() {
        runSummary = nil
        simulation = nil
        if availableTokens > 0 {
            startRun()
        } else {
            screen = .home
        }
    }

    func returnHome() {
        movementIntent = .zero
        simulation = nil
        runSummary = nil
        screen = .home
        arenaScene.setApplicationActive(false)
    }

    func applicationDidBecomeInactive() {
        movementIntent = .zero
        arenaScene.setApplicationActive(false)
        flushPersistence(protectFromSuspension: true)
    }

    func applicationDidBecomeActive() {
        if screen == .running {
            arenaScene.setApplicationActive(true)
        }
        if !isEstablishingStepConnection,
           economyLedger?.state.hasReadableStepData == true
        {
            publishEconomy()
            refreshSteps(requestAccess: false)
            refreshDailyAverage()
        }
    }

    /// Best-effort and silent: the gauge simply keeps its last baseline
    /// (or shows none) when the statistics read fails.
    private func refreshDailyAverage() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let now = composition.now()
            guard let start = composition.calendar.date(
                byAdding: .day,
                value: -30,
                to: now
            ) else { return }
            if let average = try? await composition.stepReader.averageDailySteps(
                over: DateInterval(start: start, end: now),
                calendar: composition.calendar
            ) {
                averageDailySteps = average
            }
        }
    }

    func updateAccessibility(_ options: ArenaAccessibilityOptions) {
        arenaScene.accessibilityOptions = options
    }

    func dismissProgressMessage() {
        progressMessage = nil
    }

    /// Sends the player where Steps access actually lives.
    ///
    /// The app's own Settings page can never show it: iOS surfaces HealthKit
    /// permissions only inside the Health app, so a player sent to Settings
    /// finds Siri, Search and Cellular Data and no way to fix anything. The
    /// Health app's scheme is not a documented API, so the app's own page
    /// remains the fallback rather than the destination.
    func openSystemSettings() {
        let health = URL(string: "x-apple-health://")
        if let health, UIApplication.shared.canOpenURL(health) {
            UIApplication.shared.open(health)
            return
        }
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    func resetCorruptEconomy() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let eligibilityStart = self.composition.eligibilityBoundary(
                self.composition.now(),
                self.composition.calendar
            )
            let baseline = EconomyState(eligibilityStart: eligibilityStart)
            let record = LedgerRecord(generation: 1, state: baseline)

            do {
                try await self.composition.ledgerRepository
                    .resetCorruptState(to: record)
                let ledger = EconomyLedger(
                    state: baseline,
                    generation: 1,
                    repository: self.composition.ledgerRepository
                )
                self.economyLedger = ledger
                self.configureRefreshService(using: ledger)
                self.publishEconomy()
                self.screen = .onboarding
                self.refreshState = .idle
            } catch {
                self.refreshState = .persistenceBlocked(
                    message: "The reset couldn’t be saved. Nothing was changed — try again."
                )
            }
        }
    }

    private var isPersistenceBlocked: Bool {
        if case .persistenceBlocked = refreshState {
            return true
        }
        return economyLedger?.persistenceFailure == true
    }

    private func bootstrap() async {
        do {
            do {
                playerProgress = try await composition.progressRepository.load()
            } catch {
                playerProgress = PlayerProgressState()
                progressMessage = "Your run history couldn’t be loaded. You can still play — new runs will be saved."
            }

            guard let record = try await composition.ledgerRepository.load() else {
                screen = .onboarding
                refreshState = .idle
                return
            }

            let ledger = EconomyLedger(
                state: record.state,
                generation: record.generation,
                repository: composition.ledgerRepository
            )
            economyLedger = ledger
            configureRefreshService(using: ledger)
            publishEconomy()
            if ledger.state.hasReadableStepData {
                screen = .home
                refreshSteps(requestAccess: false)
                refreshDailyAverage()
            } else {
                screen = .onboarding
                refreshState = .idle
            }
        } catch {
            screen = .economyRecovery
            refreshState = .persistenceBlocked(
                message: "Your saved step bank couldn’t be opened."
            )
        }
    }

    private func configureRefreshService(using ledger: EconomyLedger) {
        refreshService = StepRefreshService(
            reader: composition.stepReader,
            intervalProvider: { [weak self, weak ledger] in
                guard let self, let ledger else {
                    throw GameCoordinatorError.missingLedger
                }
                let start = ledger.state.eligibilityStart
                let end = max(start, self.composition.now())
                return DateInterval(start: start, end: end)
            },
            submit: { [weak ledger] total in
                guard let ledger else {
                    throw GameCoordinatorError.missingLedger
                }
                return try await ledger.reconcile(total)
            }
        )
    }

    func establishStepConnection() async {
        guard !isEstablishingStepConnection else { return }
        isEstablishingStepConnection = true
        defer { isEstablishingStepConnection = false }

        refreshState = .refreshing
        let ledger: EconomyLedger
        let createdLedgerForAttempt: Bool
        if let economyLedger {
            ledger = economyLedger
            createdLedgerForAttempt = false
        } else {
            do {
                try await composition.stepReader.requestAccess()
            } catch is CancellationError {
                refreshState = .recoverableFailure(
                    message: Self.interruptedConnectionMessage
                )
                return
            } catch {
                refreshState = .recoverableFailure(
                    message: "AFK Relay couldn’t finish setting up step access. Try again, or check Health › Sharing › Apps › AFK Relay."
                )
                return
            }

            let eligibilityStart = composition.eligibilityBoundary(
                composition.now(),
                composition.calendar
            )
            ledger = EconomyLedger(
                state: EconomyState(eligibilityStart: eligibilityStart),
                repository: composition.ledgerRepository
            )
            economyLedger = ledger
            configureRefreshService(using: ledger)
            publishEconomy()
            createdLedgerForAttempt = true
        }

        if ledger.persistenceFailure {
            do {
                try await ledger.retryPersistence()
            } catch {
                refreshState = .persistenceBlocked(
                    message: "Your step bank couldn’t be saved. Try again before starting a run."
                )
                return
            }
        }

        let outcome = await performRefresh(
            requestAccess: !createdLedgerForAttempt
        )
        if outcome == .current, ledger.state.hasReadableStepData {
            screen = .home
            refreshDailyAverage()
        } else if createdLedgerForAttempt, !ledger.persistenceFailure {
            // A genuine first connection is the first validated aggregate, not
            // merely a button tap. An unreadable/interrupted attempt must not
            // freeze an earlier day's eligibility boundary.
            economyLedger = nil
            refreshService = nil
            publishEconomy()
        }
    }

    private func performRefresh(
        requestAccess: Bool
    ) async -> StepRefreshOutcome {
        guard let refreshService else {
            refreshState = .recoverableFailure(
                message: "AFK Relay isn’t connected to Apple Health yet. Tap Connect Steps to get started."
            )
            return .recoverableFailure
        }
        refreshState = .refreshing

        do {
            let result = try await refreshService.refresh(
                requestAccess: requestAccess
            )
            publishEconomy()
            refreshState = .current(lastUpdated: result.observedAt)
            return .current
        } catch HealthKitStepReaderError.noReadableStepData {
            publishEconomy()
            refreshState = .noReadableStepData
            return .noReadableData
        } catch EconomyLedgerError.persistenceFailed {
            blockForPersistenceFailure()
            return .persistenceBlocked
        } catch is CancellationError {
            if screen == .onboarding {
                refreshState = .recoverableFailure(
                    message: Self.interruptedConnectionMessage
                )
            }
            return .cancelled
        } catch {
            publishEconomy()
            refreshState = .recoverableFailure(
                message: "AFK Relay couldn’t read a step total. Try again, or check Health › Sharing › Apps › AFK Relay."
            )
            return .recoverableFailure
        }
    }

    private func advanceFixedStep(duration: TimeInterval) -> ArenaRenderSnapshot? {
        guard
            screen == .running,
            let economyLedger,
            !economyLedger.persistenceFailure,
            var simulation
        else {
            if economyLedger?.persistenceFailure == true {
                blockForPersistenceFailure()
            }
            return nil
        }

        let normalizedIntent = movementIntent.length > 1
            ? movementIntent.normalized
            : movementIntent
        let desiredDistance = simulation.balance.playerSpeed
            * duration
            * normalizedIntent.length
        let reservation = MovementCostPolicy.reserve(
            distance: desiredDistance,
            state: economyLedger.state
        )
        let inputScale = desiredDistance > 0
            ? reservation.affordableDistance / desiredDistance
            : 0
        let affordableIntent = normalizedIntent * inputScale
        let previousPosition = simulation.player.position
        let intendedPosition = previousPosition
            + affordableIntent * simulation.balance.playerSpeed * duration
        let previousSpend = economyLedger.state.lifetimeTokensSpent
        let events = simulation.step(
            input: affordableIntent,
            duration: duration
        )
        _ = economyLedger.commitMovement(
            distance: simulation.lastPlayerTravelDistance
        )
        let spendDelta = economyLedger.state.lifetimeTokensSpent - previousSpend
        simulation.recordMovementTokensSpent(spendDelta)
        self.simulation = simulation

        availableTokens = economyLedger.state.availableTokens
        playerHealth = simulation.player.hitPoints
        survivalDuration = simulation.elapsed
        tokensSpentThisRun = economyLedger.state.lifetimeTokensSpent
            - runStartingLifetimeSpend
        process(events)

        let rendered = ArenaSnapshotPresentationAdapter.makeSnapshot(
            from: simulation.snapshot,
            events: events,
            previousPlayerPosition: previousPosition,
            intendedPlayerPosition: intendedPosition,
            balance: simulation.balance,
            renderedFramesPerSecond: arenaScene.renderedFramesPerSecond
        )

        if economyLedger.persistenceFailure {
            blockForPersistenceFailure()
        } else if events.contains(.playerDefeated) {
            soundPlayer.play(.gameOver)
            completeRun()
        }

        return rendered
    }

    private func process(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .tutorialCompleted:
                guard !playerProgress.tutorialCompleted else { continue }
                playerProgress.markTutorialCompleted()
                persistProgress(playerProgress)
            case .enemyDefeated:
                friendlyFireDefeatsThisRun += 1
            case .spawned, .damaged, .playerDefeated, .tutorialAdvanced:
                break
            }
        }
    }

    private func completeRun() {
        guard let simulation, let economyLedger else { return }
        movementIntent = .zero
        arenaScene.setApplicationActive(false)

        let record = LocalRunRecord(
            survivalDuration: simulation.elapsed,
            friendlyFireDefeats: friendlyFireDefeatsThisRun,
            tokensSpent: economyLedger.state.lifetimeTokensSpent
                - runStartingLifetimeSpend,
            endedAt: composition.now()
        )
        let update = playerProgress.record(record)
        playerProgress = update.state
        runSummary = RunSummaryModel(
            survivalDuration: record.survivalDuration,
            friendlyFireDefeats: record.friendlyFireDefeats,
            tokensSpent: record.tokensSpent,
            bestSurvivalDuration: playerProgress.bestSurvivalDuration,
            bestFriendlyFireDefeats: playerProgress.bestFriendlyFireDefeats,
            isNewSurvivalBest: update.isNewSurvivalBest,
            isNewFriendlyFireBest: update.isNewFriendlyFireBest
        )
        screen = .runSummary
        persistProgress(playerProgress)
        flushPersistence()
    }

    private func persistProgress(_ state: PlayerProgressState) {
        progressPersistence.enqueue(state)
    }

    private func publishEconomy() {
        availableTokens = economyLedger?.state.availableTokens ?? 0
    }

    private func flushPersistence(protectFromSuspension: Bool = false) {
        let economyLedger = economyLedger
        let progressPersistence = progressPersistence
        if protectFromSuspension {
            beginBackgroundPersistenceTask()
        }
        lifecycleFlushTask = Task { @MainActor [weak self] in
            defer {
                if protectFromSuspension {
                    self?.endBackgroundPersistenceTask()
                }
            }
            if let economyLedger {
                do {
                    try await economyLedger.flush()
                    self?.publishEconomy()
                } catch {
                    self?.blockForPersistenceFailure()
                }
            }

            do {
                try await progressPersistence.flush()
            } catch {
                self?.progressMessage = "Your run history couldn’t be saved to this iPhone."
            }
        }
    }

    private func beginBackgroundPersistenceTask() {
        guard backgroundTaskIdentifier == .invalid else { return }
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "AFKRelay local persistence checkpoint"
        ) { [weak self] in
            Task { @MainActor in
                self?.blockForPersistenceFailure()
                self?.endBackgroundPersistenceTask()
            }
        }
    }

    private func endBackgroundPersistenceTask() {
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }

    private func blockForPersistenceFailure() {
        movementIntent = .zero
        arenaScene.setApplicationActive(false)
        if screen == .running {
            screen = .paused
        }
        refreshState = .persistenceBlocked(
            message: "Your step bank couldn’t be saved, so the run is paused. Try again to keep playing."
        )
    }
}
