import SwiftUI

/// The arena's status readout, mounted as a system toolbar item so iOS
/// owns its position, height, and Liquid Glass treatment. One line:
/// hearts, elapsed time, and the stamina bar with its count.
struct ArenaHUDStatusChip: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ArenaHUDModel

    var body: some View {
        content
            .padding(.horizontal, AFKRelayUIStyle.standardSpacing)
            .padding(.vertical, AFKRelayUIStyle.compactSpacing)
            .modifier(ChipBackground(contrast: contrast))
    }

    // Principal toolbar items receive no automatic glass pod; the chip
    // supplies its own capsule to match the system's.
    private var content: some View {
        HStack(spacing: 6) {
            hearts
            elapsed
            HUDResourceBar(
                systemImage: "shoeprints.fill",
                tint: AFKRelayUIStyle.player,
                fraction: model.staminaFraction,
                valueText: model.availableTokens
                    .formatted(.number.grouping(.automatic)),
                accessibilityLabel: "Movement tokens",
                accessibilityValue: "\(model.availableTokens)"
            )

            // Reserved seam for future meditation-powered spells; hidden
            // until that resource exists so an empty gauge cannot confuse
            // testers.
            // HUDResourceBar(
            //     systemImage: "sparkles",
            //     tint: AFKRelayUIStyle.mana,
            //     fraction: 0,
            //     accessibilityLabel: "Mana",
            //     accessibilityValue: "Not yet available"
            // )
        }
        .font(.footnote)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("arena-hud")
    }

    private var elapsed: some View {
        Text(
            Duration.seconds(model.survivalDuration)
                .formatted(.time(pattern: .minuteSecond))
        )
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .accessibilityLabel("Survived")
        .accessibilityValue(
            Duration.seconds(model.survivalDuration)
                .formatted(.units(allowed: [.minutes, .seconds], width: .wide))
        )
    }

    private var hearts: some View {
        HStack(spacing: 3) {
            if model.maximumPlayerHealth <= 5,
               !dynamicTypeSize.isAccessibilitySize
            {
                // Lost points change glyph shape as well as tint so the
                // distinction never rests on color alone.
                ForEach(0..<model.maximumPlayerHealth, id: \.self) { index in
                    Image(systemName: lifeSymbol(at: index))
                        .foregroundStyle(
                            index < model.playerHealth
                                ? AFKRelayUIStyle.enemy
                                : .secondary
                        )
                }
            } else {
                Image(systemName: "heart.fill")
                    .foregroundStyle(AFKRelayUIStyle.enemy)
                Text("\(model.playerHealth)/\(model.maximumPlayerHealth)")
                    .monospacedDigit()
                    .bold()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Player life")
        .accessibilityValue(
            "\(model.playerHealth) of \(model.maximumPlayerHealth)"
        )
    }

    private func lifeSymbol(at index: Int) -> String {
        if index < model.playerHealth {
            "heart.fill"
        } else {
            differentiateWithoutColor ? "heart.slash" : "heart"
        }
    }
}

private struct ChipBackground: ViewModifier {
    let contrast: ColorSchemeContrast

    func body(content: Content) -> some View {
        if contrast == .increased {
            content.background(AFKRelayUIStyle.panel, in: .capsule)
        } else {
            content.glassEffect()
        }
    }
}
