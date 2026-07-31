import SwiftUI

struct DiagnosticsOverlayView: View {
    let model: ArenaDiagnosticsHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SIMULATION")
                .bold()
            Text("Fixed step \(model.fixedStepHz) Hz")
            Text("Render \(model.renderedFramesPerSecond) fps")
            Text("Tick \(model.simulationTick)")
            Text("Enemies \(model.livingEnemies) · Attacks \(model.activeAttacks)")
        }
        .font(.footnote.monospaced())
        .padding(AFKRelayUIStyle.compactSpacing)
        .background(.black.opacity(0.86), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white, lineWidth: 1)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Simulation diagnostics")
        .accessibilityIdentifier("diagnostics-overlay")
    }
}
