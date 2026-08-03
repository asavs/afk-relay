import SwiftUI

struct DiagnosticPanel<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast

    /// Overlay panels float above live danger geometry and stay translucent
    /// enough that a telegraph sliding beneath them remains visible.
    /// Increased contrast always wins with a solid fill.
    var isOverlay = false
    @ViewBuilder let content: Content

    var body: some View {
        // Adaptive chrome keeps every card native to the running iOS;
        // increased contrast gets a solid opaque fill instead of
        // translucency, whichever material the OS would otherwise use.
        if contrast == .increased {
            content
                .padding(AFKRelayUIStyle.standardSpacing)
                .background(
                    AFKRelayUIStyle.panel,
                    in: .rect(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                        .stroke(.white, lineWidth: 2)
                }
        } else {
            content
                .padding(AFKRelayUIStyle.standardSpacing)
                .afkChromeBackground(
                    in: .rect(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                )
        }
    }
}
