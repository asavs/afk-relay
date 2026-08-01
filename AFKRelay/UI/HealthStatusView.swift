import SwiftUI

struct HealthStatusView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var gaugeWidth = 120.0

    let current: Int
    let maximum: Int

    var body: some View {
        DiagnosticPanel(isOverlay: true) {
            VStack(alignment: .trailing, spacing: AFKRelayUIStyle.compactSpacing) {
                // "Life", never "Health": this is the game stat, and it must
                // not read as a display of Apple Health data.
                Label("Life", systemImage: "shield.lefthalf.filled")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // One glyph per point only at readable counts and sizes; a
                // wide-open balance or accessibility text size degrades to a
                // bounded gauge instead of laying out rows of glyphs (which
                // can stretch the arena's Metal drawable past its maximum).
                if maximum <= Self.heartGlyphLimit,
                   !dynamicTypeSize.isAccessibilitySize
                {
                    HStack(spacing: 5) {
                        ForEach(0..<maximum, id: \.self) { index in
                            Image(systemName: healthSymbol(at: index))
                                .foregroundStyle(
                                    index < current ? AFKRelayUIStyle.enemy : .secondary
                                )
                        }
                    }
                } else {
                    ProgressView(
                        value: Double(current),
                        total: Double(max(maximum, 1))
                    )
                    .tint(AFKRelayUIStyle.enemy)
                    .frame(width: gaugeWidth)
                }

                Text("\(current) of \(maximum)")
                    .font(.callout)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Player life")
        .accessibilityValue("\(current) of \(maximum)")
    }

    private static let heartGlyphLimit = 10

    // Remaining health reads by fill; under Differentiate Without Color the
    // lost hearts also change glyph shape so the distinction never rests on
    // the red tint alone.
    private func healthSymbol(at index: Int) -> String {
        if index < current {
            "heart.fill"
        } else {
            differentiateWithoutColor ? "heart.slash" : "heart"
        }
    }
}
