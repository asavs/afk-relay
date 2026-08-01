import SwiftUI

struct RunSummaryView: View {
    let model: RunSummaryModel
    let onRunAgain: @MainActor () -> Void
    let onReturnHome: @MainActor () -> Void

    var body: some View {
        ZStack {
            DiagnosticBackdropView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AFKRelayUIStyle.generousSpacing) {
                    AvatarBadgeView(isDefeated: true)

                    VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                        Text("Run Over")
                            .font(.largeTitle)
                            .bold()
                            .accessibilityAddTraits(.isHeader)

                        Text("Unspent tokens stay in your movement bank.")
                            .foregroundStyle(.secondary)
                    }

                    RunMetricsGrid(model: model)

                    if model.friendlyFireDefeats == 0 {
                        Label(
                            "Lure enemies into each other’s sweeps — their attacks are your only weapon.",
                            systemImage: "lightbulb"
                        )
                        .font(.callout)
                        .foregroundStyle(AFKRelayUIStyle.warning)
                    }

                    Text("Runs are recorded on this iPhone only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    DiagnosticPanel {
                        VStack(alignment: .leading, spacing: AFKRelayUIStyle.standardSpacing) {
                            Label("Personal Bests", systemImage: "trophy.fill")
                                .font(.headline)

                            LabeledContent("Survival") {
                                HStack(spacing: AFKRelayUIStyle.compactSpacing) {
                                    if model.isNewSurvivalBest {
                                        Image(systemName: "sparkles")
                                            .accessibilityLabel("New best")
                                    }
                                    Text(
                                        Duration.seconds(model.bestSurvivalDuration)
                                            .formatted(.time(pattern: .minuteSecond))
                                    )
                                    .monospacedDigit()
                                }
                            }

                            LabeledContent("Enemies baited") {
                                HStack(spacing: AFKRelayUIStyle.compactSpacing) {
                                    if model.isNewFriendlyFireBest {
                                        Image(systemName: "sparkles")
                                            .accessibilityLabel("New best")
                                    }
                                    Text(model.bestFriendlyFireDefeats, format: .number)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                }
                .padding(AFKRelayUIStyle.screenPadding)
            }
            .scrollIndicators(.automatic)
            // Scoped before the toolbar joins so it cannot cascade over it.
            .accessibilityIdentifier("run-summary")
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Return Home", systemImage: "house", action: onReturnHome)
                    .accessibilityIdentifier("return-home")

                Spacer()

                Button(action: onRunAgain) {
                    Label("Run Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, AFKRelayUIStyle.standardSpacing)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("run-again")
            }
        }
    }
}
