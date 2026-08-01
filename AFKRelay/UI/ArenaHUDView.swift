import SwiftUI

struct ArenaHUDView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ArenaHUDModel
    let onPause: @MainActor () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
                    bankAndTime
                    HStack(alignment: .bottom) {
                        health
                        Spacer(minLength: 0)
                        pauseButton
                    }
                }
            } else {
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
                    "\(model.availableTokens) tokens",
                    systemImage: "shoeprints.fill"
                )
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())

                Label(
                    Duration.seconds(model.survivalDuration)
                        .formatted(.time(pattern: .minuteSecond)),
                    systemImage: "stopwatch"
                )
                .monospacedDigit()

                Label(
                    "\(model.tokensSpentThisRun) spent",
                    systemImage: "arrow.down.right"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
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
