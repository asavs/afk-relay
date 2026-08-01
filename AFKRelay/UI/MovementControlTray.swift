import SwiftUI

struct MovementControlTray: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let availableTokens: Int64
    let isRunActive: Bool
    let onIntentChanged: @MainActor (MovementIntent) -> Void

    var body: some View {
        VStack(spacing: AFKRelayUIStyle.compactSpacing) {
            VirtualJoystickView(
                isEnabled: availableTokens > 0 && isRunActive,
                disabledAccessibilityValue: isRunActive
                    ? "Out of movement tokens — walk to earn more"
                    : "Run paused",
                onIntentChanged: onIntentChanged
            )

            Label(statusText, systemImage: statusSymbol)
                .font(.callout)
                .bold()
                .foregroundStyle(
                    availableTokens > 0 && isRunActive
                        ? .primary
                        : AFKRelayUIStyle.warning
                )
                .monospacedDigit()
                .accessibilityIdentifier("movement-bank-status")
        }
        .padding(.horizontal, AFKRelayUIStyle.screenPadding)
        .padding(.vertical, AFKRelayUIStyle.compactSpacing)
        .frame(maxWidth: .infinity)
        // The background extends under the home indicator; only the
        // content respects the safe area.
        .background {
            Rectangle()
                .fill(
                    reduceTransparency
                        ? AnyShapeStyle(AFKRelayUIStyle.panel)
                        : AnyShapeStyle(.ultraThinMaterial)
                )
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var statusText: String {
        if !isRunActive {
            "Run paused"
        } else if availableTokens > 0 {
            "\(availableTokens.formatted(.number.grouping(.automatic))) movement tokens"
        } else {
            "Out of tokens — walk to earn more"
        }
    }

    private var statusSymbol: String {
        if !isRunActive {
            // Paused is the only state that may say pause.
            "pause.circle.fill"
        } else if availableTokens > 0 {
            "shoeprints.fill"
        } else {
            "figure.walk"
        }
    }
}
