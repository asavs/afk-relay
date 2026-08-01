import SwiftUI

/// One thin strip: the arena below it belongs to the game. Reads
/// tokens · elapsed · life, with pause as the only control.
struct ArenaHUDView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: ArenaHUDModel
    let onPause: @MainActor () -> Void

    var body: some View {
        // Size-driven: the two-line layout engages the moment the strip
        // stops fitting, well before accessibility type sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AFKRelayUIStyle.standardSpacing) {
                strip
                pauseButton
            }

            VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
                tokens
                HStack(alignment: .center) {
                    elapsed
                    Spacer(minLength: AFKRelayUIStyle.compactSpacing)
                    life
                    Spacer(minLength: AFKRelayUIStyle.compactSpacing)
                    pauseButton
                }
            }
        }
        .padding(.horizontal, AFKRelayUIStyle.standardSpacing)
        .padding(.vertical, AFKRelayUIStyle.compactSpacing)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("arena-hud")
    }

    private var strip: some View {
        DiagnosticPanel(isOverlay: true) {
            HStack(spacing: AFKRelayUIStyle.standardSpacing) {
                tokens
                Spacer(minLength: AFKRelayUIStyle.compactSpacing)
                elapsed
                Spacer(minLength: AFKRelayUIStyle.compactSpacing)
                life
            }
        }
    }

    private var tokens: some View {
        Label(
            model.availableTokens.formatted(.number.grouping(.automatic)),
            systemImage: "shoeprints.fill"
        )
        .bold()
        .monospacedDigit()
        .accessibilityLabel("Movement tokens")
        .accessibilityValue("\(model.availableTokens)")
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

    private var life: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.secondary)

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
