import SwiftUI

struct DiagnosticPanel<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast

    /// Overlay panels float above live danger geometry and stay translucent
    /// enough that a telegraph sliding beneath them remains visible.
    /// Increased contrast always wins with a solid fill.
    var isOverlay = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(AFKRelayUIStyle.standardSpacing)
            .background(
                AFKRelayUIStyle.panel.opacity(
                    contrast == .increased ? 1 : (isOverlay ? 0.72 : 0.92)
                ),
                in: .rect(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                    .stroke(
                        contrast == .increased ? .white : AFKRelayUIStyle.player.opacity(0.45),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
    }
}
