import SwiftUI

struct GameHomeView: View {
    let availableTokens: Int64
    let canStartRun: Bool
    let refreshState: WalletRefreshPresentationState
    let onStartRun: @MainActor () -> Void
    let onRefreshSteps: @MainActor () -> Void
    let onShowSettings: @MainActor () -> Void

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

                        Text("Real movement. Tactical survival.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
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
                            .disabled(!refreshState.permitsManualRetry)
                            .frame(minHeight: AFKRelayUIStyle.minimumTapTarget)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Start Run", systemImage: "play.fill", action: onStartRun)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!canStartRun)
                        .frame(minHeight: AFKRelayUIStyle.minimumTapTarget)
                        .accessibilityIdentifier("start-run")

                    if availableTokens == 0 {
                        Label("Walk to add movement before starting.", systemImage: "shoeprints.fill")
                            .font(.callout)
                            .foregroundStyle(AFKRelayUIStyle.warning)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(AFKRelayUIStyle.screenPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gear", action: onShowSettings)
                    .accessibilityIdentifier("home-settings")
            }
        }
        .accessibilityIdentifier("game-home")
    }
}
