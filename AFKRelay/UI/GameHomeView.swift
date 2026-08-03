import SwiftUI

struct GameHomeView: View {
    let availableTokens: Int64
    let canStartRun: Bool
    let refreshState: WalletRefreshPresentationState
    let hasRunRecords: Bool
    let bestSurvivalDuration: TimeInterval
    let bestFriendlyFireDefeats: Int
    let onStartRun: @MainActor () -> Void
    let onRefreshSteps: @MainActor () -> Void
    let onShowSettings: @MainActor () -> Void

    private var startBlockedReason: String? {
        if availableTokens == 0 {
            "Walk to bank steps before you start."
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
                    VStack(spacing: AFKRelayUIStyle.standardSpacing) {
                        AvatarBadgeView()

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
                    }

                    WalletBankView(availableTokens: availableTokens)

                    // The wallet refresh is maintenance, not play: one quiet
                    // row, with retry tucked behind an icon.
                    HStack(alignment: .top, spacing: AFKRelayUIStyle.compactSpacing) {
                        WalletRefreshStatusView(state: refreshState)
                        Spacer(minLength: 0)
                        Button(
                            "Refresh Steps",
                            systemImage: "arrow.clockwise",
                            action: onRefreshSteps
                        )
                        .labelStyle(.iconOnly)
                        .afkChromeButtonStyle()
                        .buttonBorderShape(.circle)
                        .disabled(!refreshState.permitsManualRetry)
                    }
                    .padding(.horizontal, AFKRelayUIStyle.compactSpacing)

                    if hasRunRecords {
                        DiagnosticPanel {
                            VStack(alignment: .leading, spacing: AFKRelayUIStyle.standardSpacing) {
                                Label("Personal Bests", systemImage: "trophy.fill")
                                    .font(.headline)

                                LabeledContent("Survival") {
                                    Text(
                                        Duration.seconds(bestSurvivalDuration)
                                            .formatted(.time(pattern: .minuteSecond))
                                    )
                                    .monospacedDigit()
                                }

                                LabeledContent("Enemies baited") {
                                    Text(bestFriendlyFireDefeats, format: .number)
                                        .monospacedDigit()
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        DiagnosticPanel {
                            Label(
                                "Bait enemies into hitting each other — you have no weapon.",
                                systemImage: "lightbulb"
                            )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                }
                .padding(AFKRelayUIStyle.screenPadding)
            }
            .scrollIndicators(.automatic)
            // Scoped before the toolbar joins so it cannot cascade over it.
            .accessibilityIdentifier("game-home")
            // The disabled-launch reason reads above the bar it explains.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let startBlockedReason {
                    Label(startBlockedReason, systemImage: "shoeprints.fill")
                        .font(.callout)
                        .foregroundStyle(AFKRelayUIStyle.warning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AFKRelayUIStyle.screenPadding)
                        .padding(.bottom, AFKRelayUIStyle.compactSpacing)
                }
            }
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        // The system bottom bar: icon pods flanking the labeled launch pod —
        // (Settings) (       Start Run       ) (Trophy). Text-only buttons
        // keep their words in a bar; icon+text labels collapse to the icon.
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Settings", systemImage: "gearshape", action: onShowSettings)
                    .accessibilityIdentifier("home-settings")

                Spacer()

                Button(action: onStartRun) {
                    // A plain HStack, not a Label: bars reformat Labels to
                    // icon-only, so the pairing is hand-made — which means
                    // padding and the accessibility label are ours to supply.
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start Run!")
                    }
                    .font(.headline)
                    .padding(.horizontal, AFKRelayUIStyle.standardSpacing)
                }
                    .afkChromeButtonStyle(prominent: true)
                    .disabled(!canStartRun)
                    .accessibilityLabel("Start Run")
                    .accessibilityHint(startBlockedReason ?? "")
                    .accessibilityIdentifier("start-run")

                Spacer()

                Button("Leaderboard", systemImage: "trophy") {}
                    .disabled(true)
                    .accessibilityHint("Coming later")
            }
        }
    }
}
