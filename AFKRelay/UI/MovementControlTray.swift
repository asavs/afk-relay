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

            // The HUD already shows the live token count; the tray speaks
            // only when something needs attention.
            if let statusText {
                Label(statusText, systemImage: statusSymbol)
                    .font(.callout)
                    .bold()
                    .foregroundStyle(AFKRelayUIStyle.warning)
                    .monospacedDigit()
                    .accessibilityIdentifier("movement-bank-status")
            }
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

    // Paused state is announced by the pause overlay; the tray only warns
    // about an empty bank.
    private var statusText: String? {
        if isRunActive, availableTokens == 0 {
            "Out of tokens — walk to earn more"
        } else {
            nil
        }
    }

    private var statusSymbol: String {
        "figure.walk"
    }
}
