import SwiftUI

struct GameHomeView: View {
    let availableTokens: Int64
    let canStartRun: Bool
    let refreshState: WalletRefreshPresentationState
    let onStartRun: @MainActor () -> Void
    let onRefreshSteps: @MainActor () -> Void
    let onShowSettings: @MainActor () -> Void

    private var startBlockedReason: String? {
        if availableTokens == 0 {
            "Walk to earn movement tokens before you start."
        } else if !canStartRun {
            "Resolve the save issue above before starting a run."
        } else {
            nil
        }
    }

    var body: some View {
        ZStack {
            DiagnosticBackdropView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AFKRelayUIStyle.generousSpacing) {
                    VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                        Text("AFK RELAY")
                            .font(.largeTitle)
                            .bold()
                            .tracking(2)
                            .minimumScaleFactor(0.7)
                            .accessibilityLabel("AFK Relay")
                            .accessibilityAddTraits(.isHeader)

                        Text("Real movement. Tactical survival.")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Bait enemies into hitting each other — you have no weapon.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    WalletBankView(availableTokens: availableTokens)

                    DiagnosticPanel {
                        VStack(alignment: .leading, spacing: AFKRelayUIStyle.standardSpacing) {
                            WalletRefreshStatusView(state: refreshState)

                            Button(
                                "Refresh Steps",
                                systemImage: "arrow.clockwise",
                                action: onRefreshSteps
                            )
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(!refreshState.permitsManualRetry)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(AFKRelayUIStyle.screenPadding)
            }
            .scrollIndicators(.automatic)
            // Scoped before the inset so it cannot cascade over the dock.
            .accessibilityIdentifier("game-home")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryActionDock {
                    // The reason a disabled control is disabled reads before
                    // the control, for sighted users and VoiceOver alike.
                    if let startBlockedReason {
                        VStack(spacing: 4) {
                            Image(systemName: "shoeprints.fill")
                            Text(startBlockedReason)
                                .multilineTextAlignment(.center)
                        }
                        .font(.callout)
                        .foregroundStyle(AFKRelayUIStyle.warning)
                    }

                    Button("Start Run", systemImage: "play.fill", action: onStartRun)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canStartRun)
                        .accessibilityHint(startBlockedReason ?? "")
                        .accessibilityIdentifier("start-run")
                }
            }
        }
        .foregroundStyle(.white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape", action: onShowSettings)
                    .accessibilityIdentifier("home-settings")
            }
        }
    }
}
