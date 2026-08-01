import SwiftUI

/// A compact labeled resource gauge for the arena HUD: icon, capsule bar,
/// and an optional numeric readout. Purely presentational and token-styled
/// so future resources (or future art) swap in without layout changes.
struct HUDResourceBar: View {
    @ScaledMetric(relativeTo: .caption) private var barWidth = 96.0

    let systemImage: String
    let tint: Color
    let fraction: Double
    var valueText: String?
    let accessibilityLabel: String
    let accessibilityValue: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(tint)
                .frame(width: 14)

            Capsule()
                .fill(.white.opacity(0.15))
                .frame(width: barWidth, height: 6)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth * min(max(fraction, 0), 1))
                }

            if let valueText {
                Text(valueText)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}
