import SwiftUI

/// Pins a screen's primary actions to the bottom safe area so they stay in
/// comfortable thumb reach, with a background that extends under the home
/// indicator and honors Reduce Transparency.
struct PrimaryActionDock<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: AFKRelayUIStyle.compactSpacing) {
            content
        }
        .padding(.horizontal, AFKRelayUIStyle.screenPadding)
        .padding(.vertical, AFKRelayUIStyle.compactSpacing)
        .frame(maxWidth: .infinity)
        .background {
            if reduceTransparency {
                Rectangle()
                    .fill(AFKRelayUIStyle.panel)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}
