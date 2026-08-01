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
        HStack(alignment: .top, spacing: AFKRelayUIStyle.compactSpacing) {
            DiagnosticPanel(isOverlay: true) {
                // Size-driven: the stacked layout engages the moment one
                // line stops fitting, well before accessibility sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: AFKRelayUIStyle.compactSpacing) {
                        elapsed
                        Spacer(minLength: AFKRelayUIStyle.compactSpacing)
                        vitals
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        elapsed
                        vitals
                    }
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)

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

    private var vitals: some View {
        VStack(alignment: .trailing, spacing: 5) {
            hearts

            HUDResourceBar(
                systemImage: "shoeprints.fill",
                tint: AFKRelayUIStyle.player,
                fraction: model.staminaFraction,
                valueText: model.availableTokens
                    .formatted(.number.grouping(.automatic)),
                accessibilityLabel: "Movement tokens",
                accessibilityValue: "\(model.availableTokens)"
            )

            // A reserved seam for future meditation-powered spells; inert
            // in the gameplay proof.
            HUDResourceBar(
                systemImage: "sparkles",
                tint: AFKRelayUIStyle.mana,
                fraction: 0,
                accessibilityLabel: "Mana",
                accessibilityValue: "Not yet available"
            )
        }
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
        .buttonStyle(.bordered)
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
