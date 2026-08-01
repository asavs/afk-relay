import SwiftUI

struct ArenaHUDView: View {
    let model: ArenaHUDModel
    let onPause: @MainActor () -> Void

    var body: some View {
        // Size-driven, not category-driven: the stacked layout engages the
        // moment the row stops fitting, which happens well before the
        // accessibility type sizes.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AFKRelayUIStyle.compactSpacing) {
                bankAndTime
                Spacer(minLength: 0)
                VStack(
                    alignment: .trailing,
                    spacing: AFKRelayUIStyle.compactSpacing
                ) {
                    health
                    pauseButton
                }
            }

            VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
                bankAndTime
                HStack(alignment: .bottom) {
                    health
                    Spacer(minLength: 0)
                    pauseButton
                }
            }
        }
        .padding(AFKRelayUIStyle.standardSpacing)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("arena-hud")
    }

    private var bankAndTime: some View {
        DiagnosticPanel {
            VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
                Label(
                    "\(model.availableTokens.formatted(.number.grouping(.automatic))) tokens",
                    systemImage: "shoeprints.fill"
                )
                .bold()
                .monospacedDigit()

                Label(
                    Duration.seconds(model.survivalDuration)
                        .formatted(.time(pattern: .minuteSecond)),
                    systemImage: "stopwatch"
                )
                .monospacedDigit()
                .accessibilityLabel("Survived")
                .accessibilityValue(
                    Duration.seconds(model.survivalDuration)
                        .formatted(.units(allowed: [.minutes, .seconds], width: .wide))
                )

                Label(
                    "\(model.tokensSpentThisRun) spent",
                    systemImage: "arrow.down.right"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("Tokens spent this run")
                .accessibilityValue("\(model.tokensSpentThisRun)")
            }
        }
    }

    private var health: some View {
        HealthStatusView(
            current: model.playerHealth,
            maximum: model.maximumPlayerHealth
        )
    }

    private var pauseButton: some View {
        // The frame lives inside the button so the whole area is tappable;
        // an outer frame would only add inert padding around the target.
        Button(action: onPause) {
            Image(systemName: "pause.fill")
                .frame(
                    minWidth: AFKRelayUIStyle.minimumTapTarget,
                    minHeight: AFKRelayUIStyle.minimumTapTarget
                )
                .contentShape(.rect)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Pause")
        .accessibilityIdentifier("pause-run")
    }
}
