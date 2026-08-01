import SwiftUI

/// The floating movement cluster: the joystick sits directly over the
/// arena like every other HUD element, with a glass warning capsule above
/// it when the bank runs dry. There is no tray band; the field owns the
/// whole screen.
struct MovementControlTray: View {
    @Environment(\.colorSchemeContrast) private var contrast

    let availableTokens: Int64
    let isRunActive: Bool
    let onIntentChanged: @MainActor (MovementIntent) -> Void

    var body: some View {
        VStack(spacing: AFKRelayUIStyle.compactSpacing) {
            if let statusText {
                Label(statusText, systemImage: "figure.walk")
                    .font(.callout)
                    .bold()
                    .foregroundStyle(AFKRelayUIStyle.warning)
                    .monospacedDigit()
                    .padding(.horizontal, AFKRelayUIStyle.standardSpacing)
                    .padding(.vertical, AFKRelayUIStyle.compactSpacing)
                    .modifier(WarningChipBackground(contrast: contrast))
                    .accessibilityIdentifier("movement-bank-status")
            }

            VirtualJoystickView(
                isEnabled: availableTokens > 0 && isRunActive,
                disabledAccessibilityValue: isRunActive
                    ? "Out of movement tokens — walk to earn more"
                    : "Run paused",
                onIntentChanged: onIntentChanged
            )
        }
    }

    // Paused state is announced by the pause overlay; the cluster only
    // warns about an empty bank.
    private var statusText: String? {
        if isRunActive, availableTokens == 0 {
            "Out of tokens — walk to earn more"
        } else {
            nil
        }
    }
}

private struct WarningChipBackground: ViewModifier {
    let contrast: ColorSchemeContrast

    func body(content: Content) -> some View {
        if contrast == .increased {
            content.background(AFKRelayUIStyle.panel, in: .capsule)
        } else {
            content.glassEffect()
        }
    }
}
