import SwiftUI

struct MovementControlTray: View {
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
        .background(.ultraThinMaterial)
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
        availableTokens > 0 && isRunActive
            ? "shoeprints.fill"
            : "pause.circle.fill"
    }
}
