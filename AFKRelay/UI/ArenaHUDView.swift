import SwiftUI

/// One thin strip: elapsed time on the left; hearts, stamina, and the
/// future mana reserve on the right; pause as the only control. The arena
/// below it belongs to the game.
struct ArenaHUDView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ArenaHUDModel
    let onPause: @MainActor () -> Void

    var body: some View {
        // A compact glass chip floats top-leading; pause floats trailing.
        // Both are overlays on the arena, never part of the field.
        HStack(alignment: .top) {
            DiagnosticPanel(isOverlay: true) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: AFKRelayUIStyle.compactSpacing) {
                        hearts
                        elapsed
                    }

                    HUDResourceBar(
                        systemImage: "shoeprints.fill",
                        tint: AFKRelayUIStyle.player,
                        fraction: model.staminaFraction,
                        valueText: model.availableTokens
                            .formatted(.number.grouping(.automatic)),
                        accessibilityLabel: "Movement tokens",
                        accessibilityValue: "\(model.availableTokens)"
                    )

                    // Reserved seam for future meditation-powered spells;
                    // hidden until that resource exists so the empty gauge
                    // cannot confuse testers.
                    // HUDResourceBar(
                    //     systemImage: "sparkles",
                    //     tint: AFKRelayUIStyle.mana,
                    //     fraction: 0,
                    //     accessibilityLabel: "Mana",
                    //     accessibilityValue: "Not yet available"
                    // )
                }
                .font(.footnote)
            }

            Spacer(minLength: AFKRelayUIStyle.compactSpacing)

            pauseButton
        }
        .padding(.horizontal, AFKRelayUIStyle.standardSpacing)
        .padding(.vertical, AFKRelayUIStyle.compactSpacing)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("arena-hud")
    }

    private var elapsed: some View {
        Label(
            Duration.seconds(model.survivalDuration)
                .formatted(.time(pattern: .minuteSecond)),
            systemImage: "stopwatch"
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
        HStack(spacing: 4) {
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

    private var pauseButton: some View {
        // The frame lives inside the button so the whole area is tappable.
        // Neutral tint: the player's cyan belongs to the player alone.
        Button(action: onPause) {
            Image(systemName: "pause.fill")
                .frame(
                    minWidth: AFKRelayUIStyle.minimumTapTarget,
                    minHeight: AFKRelayUIStyle.minimumTapTarget
                )
                .contentShape(.rect)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .foregroundStyle(.white)
        .accessibilityLabel("Pause")
        .accessibilityIdentifier("pause-run")
    }

    private func lifeSymbol(at index: Int) -> String {
        if index < model.playerHealth {
            "heart.fill"
        } else {
            differentiateWithoutColor ? "heart.slash" : "heart"
        }
    }
}
