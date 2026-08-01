import SwiftUI

struct DiagnosticPanel<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast

    /// Overlay panels float above live danger geometry and stay translucent
    /// enough that a telegraph sliding beneath them remains visible.
    /// Increased contrast always wins with a solid fill.
    var isOverlay = false
    @ViewBuilder let content: Content

    var body: some View {
        // System materials keep every card native; increased contrast gets
        // a solid opaque fill instead of translucency.
        content
            .padding(AFKRelayUIStyle.standardSpacing)
            .background(
                contrast == .increased
                    ? AnyShapeStyle(AFKRelayUIStyle.panel)
                    : (isOverlay
                        ? AnyShapeStyle(.thinMaterial)
                        : AnyShapeStyle(.regularMaterial)),
                in: .rect(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
            )
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                        .stroke(.white, lineWidth: 2)
                }
            }
    }
}
