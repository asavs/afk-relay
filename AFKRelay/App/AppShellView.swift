import SpriteKit
import SwiftUI

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var coordinator: GameCoordinator
    @State private var showsSettings = false
    @State private var showsResetConfirmation = false

    init(composition: AppComposition = .current()) {
        _coordinator = State(
            initialValue: GameCoordinator(composition: composition)
        )
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        // The root proxy sits outside the navigation stack, so its top
        // inset is the device's honest status band — nav bars and hidden
        // status bars never distort it.
        GeometryReader { rootProxy in
            NavigationStack {
                content
            }
            // The counterfeit status bar: game surfaces hide the real one,
            // so the HUD wears its band, sized to the top inset so items
            // sit level with the sensor housing the way the system's own
            // do. In a run the slots carry run state; on menu surfaces the
            // clock is the actual time and the battery is the bank.
            .overlay(alignment: .top) {
                if let statusBarContext {
                    VStack(spacing: 0) {
                        ArenaStatusBarHUD(
                            context: statusBarContext,
                            topInset: rootProxy.safeAreaInsets.top,
                            onPause: coordinator.screen == .running
                                ? pauseRunWithSound
                                : nil
                        )
                        .frame(height: max(rootProxy.safeAreaInsets.top, 24))
                        Spacer(minLength: 0)
                            .allowsHitTesting(false)
                    }
                    .ignoresSafeArea(edges: .top)
                }
            }
        }
        .preferredColorScheme(.dark)
        // Game surfaces own their chrome; pre-game surfaces (loading,
        // onboarding, recovery) keep the system status bar.
        .statusBarHidden(statusBarContext != nil)
        .sheet(isPresented: $showsSettings) {
            GameSettingsView(
                diagnostics: $coordinator.diagnosticsOptions,
                refreshState: coordinator.refreshState,
                onRefreshSteps: refreshStepsWithSound,
                onOpenSystemSettings: openSystemSettingsWithSound,
                onDone: closeSettingsWithSound
            )
        }
        .task {
            await coordinator.start()
            publishAccessibilityOptions()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                coordinator.applicationDidBecomeActive()
            } else {
                coordinator.applicationDidBecomeInactive()
            }
        }
        .onChange(of: differentiateWithoutColor) {
            publishAccessibilityOptions()
        }
        .onChange(of: reduceMotion) {
            publishAccessibilityOptions()
        }
        .onChange(of: colorSchemeContrast) {
            publishAccessibilityOptions()
        }
        .alert(
            "Couldn’t Save Run History",
            isPresented: Binding(
                get: { coordinator.progressMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        coordinator.dismissProgressMessage()
                    }
                }
            )
        ) {
            Button("OK") { coordinator.playButtonSound() }
        } message: {
            Text(coordinator.progressMessage ?? "")
        }
    }

    private var statusBarContext: ArenaStatusBarHUD.Context? {
        switch coordinator.screen {
        case .running, .paused:
            .run(coordinator.hudModel)
        case .home, .runSummary:
            .home(
                availableTokens: coordinator.availableTokens,
                dailyAverageSteps: coordinator.averageDailySteps
            )
        case .loading, .onboarding, .economyRecovery:
            nil
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.screen {
        case .loading:
            loadingView
        case .onboarding:
            StepOnboardingView(
                refreshState: coordinator.refreshState,
                onConnectSteps: connectStepsWithSound,
                onRetry: connectStepsWithSound,
                onOpenSettings: openSystemSettingsWithSound
            )
        case .home:
            GameHomeView(
                availableTokens: coordinator.availableTokens,
                canStartRun: coordinator.canStartRun,
                refreshState: coordinator.refreshState,
                hasRunRecords: coordinator.hasRunRecords,
                bestSurvivalDuration: coordinator.bestSurvivalDuration,
                bestFriendlyFireDefeats: coordinator.bestFriendlyFireDefeats,
                onStartRun: startRunWithSound,
                onRefreshSteps: refreshStepsWithSound,
                onShowSettings: openSettingsWithSound
            )
        case .running, .paused:
            arenaView
        case .runSummary:
            if let runSummary = coordinator.runSummary {
                RunSummaryView(
                    model: runSummary,
                    onRunAgain: runAgainWithSound,
                    onReturnHome: returnHomeWithSound
                )
            } else {
                loadingView
            }
        case .economyRecovery:
            economyRecoveryView
        }
    }

    private var loadingView: some View {
        ZStack {
            DiagnosticBackdropView()
                .ignoresSafeArea()
            ProgressView("Loading your step bank…")
                .controlSize(.large)
                .foregroundStyle(.white)
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("app-loading")
    }

    private var arenaView: some View {
        ZStack(alignment: .top) {
            SpriteView(
                scene: coordinator.arenaScene,
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea()
            .accessibilityElement()
            .accessibilityLabel("Tactical survival arena")
            .accessibilityAddTraits(.allowsDirectInteraction)
            .accessibilityIdentifier("arena")

            if coordinator.diagnosticsOptions.isEnabled,
               coordinator.diagnosticsOptions.showsFrameMetrics
            {
                // Bottom-leading keeps the readout clear of both the HUD
                // band above and the danger geometry mid-arena.
                DiagnosticsOverlayView(model: coordinator.diagnosticsHUDModel)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomLeading
                    )
                    .padding(AFKRelayUIStyle.standardSpacing)
                    .allowsHitTesting(false)
            }

        }
        // The joystick floats over the arena like every other HUD element —
        // the scene ignores safe areas, so the field still renders
        // full-bleed behind it. A safe-area inset (not an overlay) keeps
        // the control outside the SpriteKit view's touch arbitration.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MovementControlTray(
                availableTokens: coordinator.availableTokens,
                isRunActive: coordinator.screen == .running,
                onIntentChanged: coordinator.setMovementIntent
            )
            .padding(.bottom, AFKRelayUIStyle.generousSpacing)
            .disabled(coordinator.screen != .running)
            .accessibilityHidden(coordinator.screen == .paused)
        }
        // The pause overlay sits above everything so pausing dims the whole
        // surface, joystick included.
        .overlay {
            if coordinator.screen == .paused {
                RunPauseOverlay(
                    onResume: resumeRunWithSound,
                    onEndRun: endRunWithSound,
                    onShowSettings: openSettingsWithSound
                )
            }
        }
        // Pause lives in the status band beside the clock; the arena
        // needs no navigation bar at all.
        .toolbar(.hidden, for: .navigationBar)
    }

    private var economyRecoveryView: some View {
        ZStack {
            DiagnosticBackdropView()
                .ignoresSafeArea()

            DiagnosticPanel {
                VStack(alignment: .leading, spacing: AFKRelayUIStyle.standardSpacing) {
                    Label(
                        "Movement Bank Needs a Reset",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.title2)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                    Text(
                        "Your saved step bank is damaged and can’t be opened. To keep playing, AFK Relay needs to start a new bank at zero steps."
                    )

                    Text(
                        "This can’t restore your previous steps. Your Apple Health data is not changed."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Button(
                        "Reset Movement Bank",
                        systemImage: "trash.fill",
                        role: .destructive,
                        action: showResetConfirmationWithSound
                    )
                    .afkChromeButtonStyle(prominent: true)
                    .controlSize(.large)
                    .confirmationDialog(
                        "Reset the step bank?",
                        isPresented: $showsResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Reset Bank", role: .destructive) {
                            resetCorruptEconomyWithSound()
                        }
                        Button("Cancel", role: .cancel) {
                            coordinator.playButtonSound()
                        }
                    } message: {
                        Text("This starts a new bank at zero steps and can’t restore the previous one.")
                    }
                }
            }
            .padding(AFKRelayUIStyle.screenPadding)
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("economy-recovery")
    }

    private func handleRetryOrRefresh() {
        if case .persistenceBlocked = coordinator.refreshState {
            coordinator.retryPersistenceAndRefresh()
        } else {
            coordinator.refreshSteps()
        }
    }

    private func performButtonAction(
        _ action: @MainActor () -> Void
    ) {
        coordinator.playButtonSound()
        action()
    }

    private func pauseRunWithSound() {
        performButtonAction(coordinator.pauseRun)
    }

    private func refreshStepsWithSound() {
        performButtonAction(handleRetryOrRefresh)
    }

    private func connectStepsWithSound() {
        performButtonAction(coordinator.connectSteps)
    }

    private func openSystemSettingsWithSound() {
        performButtonAction(coordinator.openSystemSettings)
    }

    private func startRunWithSound() {
        performButtonAction(coordinator.startRun)
    }

    private func openSettingsWithSound() {
        performButtonAction { showsSettings = true }
    }

    private func closeSettingsWithSound() {
        performButtonAction { showsSettings = false }
    }

    private func runAgainWithSound() {
        performButtonAction(coordinator.runAgain)
    }

    private func returnHomeWithSound() {
        performButtonAction(coordinator.returnHome)
    }

    private func resumeRunWithSound() {
        performButtonAction(coordinator.resumeRun)
    }

    private func endRunWithSound() {
        performButtonAction(coordinator.endRun)
    }

    private func showResetConfirmationWithSound() {
        performButtonAction { showsResetConfirmation = true }
    }

    private func resetCorruptEconomyWithSound() {
        performButtonAction(coordinator.resetCorruptEconomy)
    }

    private func publishAccessibilityOptions() {
        coordinator.updateAccessibility(
            ArenaAccessibilityOptions(
                reduceMotion: reduceMotion,
                differentiateWithoutColor: differentiateWithoutColor,
                increaseContrast: colorSchemeContrast == .increased
            )
        )
    }
}
