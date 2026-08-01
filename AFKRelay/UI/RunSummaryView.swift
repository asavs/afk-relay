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
                    Image(systemName: "flag.pattern.checkered")
                        .font(.largeTitle)
                        .foregroundStyle(AFKRelayUIStyle.player)
                        .accessibilityHidden(true)

                    VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                        Text("Run Complete")
                            .font(.largeTitle)
                            .bold()
                            .accessibilityAddTraits(.isHeader)

                        Text("Unspent tokens stay in your movement bank.")
                            .foregroundStyle(.secondary)
                    }

                    RunMetricsGrid(model: model)

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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryActionDock {
                    Button("Run Again", systemImage: "arrow.clockwise", action: onRunAgain)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("run-again")

                    Button("Return Home", systemImage: "house", action: onReturnHome)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("return-home")
                }
            }
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("run-summary")
    }
}
