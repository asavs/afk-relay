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

        NavigationStack {
            content
        }
        .preferredColorScheme(.dark)
        // Immersive chrome removal is arena-only; every other surface keeps
        // the system status bar.
        .statusBarHidden(
            coordinator.screen == .running || coordinator.screen == .paused
        )
        .sheet(isPresented: $showsSettings) {
            GameSettingsView(
                diagnostics: $coordinator.diagnosticsOptions,
                refreshState: coordinator.refreshState,
                onRefreshSteps: handleRetryOrRefresh,
                onOpenSystemSettings: coordinator.openSystemSettings,
                onDone: { showsSettings = false }
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
            Button("OK") {}
        } message: {
            Text(coordinator.progressMessage ?? "")
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
                onConnectSteps: coordinator.connectSteps,
                onRetry: coordinator.connectSteps,
                onOpenSettings: coordinator.openSystemSettings
            )
        case .home:
            GameHomeView(
                availableTokens: coordinator.availableTokens,
                canStartRun: coordinator.canStartRun,
                refreshState: coordinator.refreshState,
                onStartRun: coordinator.startRun,
                onRefreshSteps: handleRetryOrRefresh,
                onShowSettings: { showsSettings = true }
            )
        case .running, .paused:
            arenaView
        case .runSummary:
            if let runSummary = coordinator.runSummary {
                RunSummaryView(
                    model: runSummary,
                    onRunAgain: coordinator.runAgain,
                    onReturnHome: coordinator.returnHome
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
            ProgressView("Loading your movement bank…")
                .controlSize(.large)
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("app-loading")
    }

    private var arenaView: some View {
        ZStack(alignment: .top) {
            SpriteView(
                scene: coordinator.arenaScene,
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea(edges: .horizontal)
            .accessibilityLabel("Tactical survival arena")
            .accessibilityIdentifier("arena")

            ArenaHUDView(
                model: coordinator.hudModel,
                onPause: coordinator.pauseRun
            )

            if coordinator.diagnosticsOptions.isEnabled,
               coordinator.diagnosticsOptions.showsFrameMetrics
            {
                DiagnosticsOverlayView(model: coordinator.diagnosticsHUDModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding()
                    .allowsHitTesting(false)
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MovementControlTray(
                availableTokens: coordinator.availableTokens,
                isRunActive: coordinator.screen == .running,
                onIntentChanged: coordinator.setMovementIntent
            )
            .disabled(coordinator.screen != .running)
            .accessibilityHidden(coordinator.screen == .paused)
        }
        // The overlay sits above the tray inset so pausing dims the whole
        // surface, joystick included.
        .overlay {
            if coordinator.screen == .paused {
                RunPauseOverlay(
                    onResume: coordinator.resumeRun,
                    onEndRun: coordinator.endRun,
                    onShowSettings: { showsSettings = true }
                )
            }
        }
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

                    Text(
                        "Your saved movement bank is damaged and can’t be opened. To keep playing, AFK Relay needs to start a new bank at zero tokens."
                    )

                    Text(
                        "This can’t restore your previous tokens. Your Apple Health data is not changed."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)

                    Button(
                        "Reset Movement Bank",
                        systemImage: "trash.fill",
                        role: .destructive,
                        action: { showsResetConfirmation = true }
                    )
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .confirmationDialog(
                        "Reset the movement bank?",
                        isPresented: $showsResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Reset Bank", role: .destructive) {
                            coordinator.resetCorruptEconomy()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This starts a new bank at zero tokens and can’t restore the previous one.")
                    }
                }
            }
            .padding(AFKRelayUIStyle.screenPadding)
        }
        .foregroundStyle(.white)
        .accessibilityIdentifier("economy-recovery")
    }

    private func handleRetryOrRefresh() {
        if case .persistenceBlocked = coordinator.refreshState {
            coordinator.retryPersistenceAndRefresh()
        } else {
            coordinator.refreshSteps()
        }
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
