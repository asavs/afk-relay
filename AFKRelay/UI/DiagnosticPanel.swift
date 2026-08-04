import SwiftUI

struct DiagnosticPanel<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast

    /// Overlay panels float above live danger geometry and stay translucent
    /// enough that a telegraph sliding beneath them remains visible.
    /// Increased contrast always wins with a solid fill.
    var isOverlay = false
    /// Liquid Glass does not nest. A glass control sitting on a glass
    /// surface has nothing left to refract, so it renders flat — the pause
    /// menu's buttons looked plain for exactly this reason while the same
    /// styles read as glass on home and the run summary, where the buttons
    /// sit over the background instead of inside a card. A panel that hosts
    /// controls therefore takes a solid fill and lets its buttons carry the
    /// material.
    var hostsControls = false
    @ViewBuilder let content: Content

    var body: some View {
        // Adaptive chrome keeps every card native to the running iOS;
        // increased contrast gets a solid opaque fill instead of
        // translucency, whichever material the OS would otherwise use.
        if contrast == .increased || hostsControls {
            content
                .padding(AFKRelayUIStyle.standardSpacing)
                .background(
                    AFKRelayUIStyle.panel,
                    in: .rect(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                )
                .overlay {
                    if contrast == .increased {
                        RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                            .stroke(.white, lineWidth: 2)
                    }
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
