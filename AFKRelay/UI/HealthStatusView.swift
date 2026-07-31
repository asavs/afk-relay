import SwiftUI

struct HealthStatusView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let current: Int
    let maximum: Int

    var body: some View {
        DiagnosticPanel {
            VStack(alignment: .trailing, spacing: AFKRelayUIStyle.compactSpacing) {
                Label("Health", systemImage: "heart.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 5) {
                    ForEach(0..<maximum, id: \.self) { index in
                        Image(systemName: healthSymbol(at: index))
                            .foregroundStyle(
                                index < current ? AFKRelayUIStyle.enemy : .secondary
                            )
                    }
                }

                Text("\(current) of \(maximum)")
                    .font(.callout)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health")
        .accessibilityValue("\(current) of \(maximum)")
    }

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
