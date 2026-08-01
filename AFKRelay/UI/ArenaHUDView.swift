import SwiftUI

/// The arena's status readout, worn as a counterfeit status bar: the run
/// hides the real one, so the HUD occupies its band and borrows its
/// grammar — the survival clock where the time lives, a heart in the
/// Wi-Fi slot, and stamina drawn as the battery. Items center inside the
/// display's "ears" beside the sensor housing, exactly as iOS lays out
/// its own.
struct ArenaStatusBarHUD: View {
    /// Which meanings the borrowed slots carry. In a run the clock is the
    /// survival timer and the battery is run stamina; on menu surfaces the
    /// clock is the actual time (the hidden system bar owes the player
    /// one) and the battery is the movement bank with its count beside it.
    enum Context {
        case run(ArenaHUDModel)
        case home(availableTokens: Int64, dailyAverageSteps: Int64)
    }


    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let context: Context
    /// The device's top safe-area inset, measured at the window root; the
    /// ear width is derived from it.
    let topInset: CGFloat
    /// Present only while a run is pausable: renders the bare pause glyph
    /// beside the clock, the way system indicators ride there.
    var onPause: (@MainActor () -> Void)? = nil

    /// The width of one "ear" — the strip between a screen edge and the
    /// centered sensor cutout. Apple publishes no API for cutout frames,
    /// so the class is inferred from the measured inset: the tall band is
    /// the Dynamic Island (~125pt wide), the short band the notch
    /// (~210pt), anything else has no cutout. iOS centers its status
    /// items inside these ears; so do we.
    private var earWidth: CGFloat? {
        if topInset >= 54 {
            134
        } else if topInset >= 44 {
            90
        } else {
            nil
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                // A mirror of the pause slot: the clock stays dead-center
                // in the ear — native position — whether pause rides
                // beside it or not.
                if onPause != nil {
                    Color.clear.frame(width: 32, height: 1)
                }

                clock

                if let onPause {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pause")
                    .accessibilityIdentifier("pause-run")
                }
            }
            .frame(width: earWidth)

            Spacer(minLength: 0)

            // The right ear keeps the system's own ordering — cellular,
            // Wi-Fi, battery — as mana, health, stamina.
            HStack(spacing: 6) {
                // The future meditation-powered mana resource in the
                // cellular-bars slot; it will hollow out as it depletes,
                // exactly like the heart. On trial for layout; the
                // resource does not exist yet, so it reads full.
                DrainingGlyph(
                    hollow: "bubbles.and.sparkles",
                    filled: "bubbles.and.sparkles.fill",
                    fraction: 1,
                    tint: AFKRelayUIStyle.mana
                )

                heart

                switch context {
                case .run(let model):
                    StaminaBatteryGauge(fraction: model.staminaFraction)
                case .home(let availableTokens, let dailyAverageSteps):
                    // A "full" charge is the player's own HealthKit
                    // trailing-30-day daily average; with no baseline the
                    // case reads full whenever anything is banked.
                    StaminaBatteryGauge(
                        fraction: dailyAverageSteps > 0
                            ? Double(availableTokens) / Double(dailyAverageSteps)
                            : (availableTokens > 0 ? 1 : 0),
                        label: availableTokens.formatted()
                    )
                }
            }
            .frame(width: earWidth)
            // One element: VoiceOver reads the resource state in a
            // breath, and the battery fill's value would otherwise be
            // unreachable.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Run status")
            .accessibilityValue(accessibilitySummary)
        }
        // Cutout-free displays get plain edge margins instead of ears.
        .padding(
            .horizontal,
            earWidth == nil
                ? AFKRelayUIStyle.generousSpacing + AFKRelayUIStyle.compactSpacing
                : 0
        )
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            isRun ? "arena-hud" : "home-status"
        )
    }

    private var isRun: Bool {
        if case .run = context { true } else { false }
    }

    private var accessibilitySummary: String {
        switch context {
        case .run(let model):
            let survived = Duration.seconds(model.survivalDuration)
                .formatted(.units(allowed: [.minutes, .seconds], width: .wide))
            return "\(model.playerHealth) of \(model.maximumPlayerHealth) hearts, "
                + "survived \(survived), "
                + "\(model.availableTokens) steps left"
        case .home(let availableTokens, _):
            return "\(availableTokens) steps banked"
        }
    }

    @ViewBuilder
    private var clock: some View {
        switch context {
        case .run(let model):
            Text(
                Duration.seconds(model.survivalDuration)
                    .formatted(.time(pattern: .minuteSecond))
            )
            .monospacedDigit()
        case .home:
            TimelineView(.everyMinute) { timelineContext in
                Text(
                    timelineContext.date,
                    format: .dateTime
                        .hour(.defaultDigits(amPM: .omitted))
                        .minute()
                )
                .monospacedDigit()
            }
        }
    }

    // One heart that empties from the top as hits land.
    private var heart: some View {
        DrainingGlyph(
            hollow: differentiateWithoutColor && heartFraction == 0
                ? "heart.slash"
                : "heart",
            filled: "heart.fill",
            fraction: heartFraction,
            tint: AFKRelayUIStyle.enemy
        )
    }

    private var heartFraction: Double {
        switch context {
        case .run(let model):
            guard model.maximumPlayerHealth > 0 else { return 0 }
            return max(
                0,
                min(1, Double(model.playerHealth) / Double(model.maximumPlayerHealth))
            )
        case .home:
            // Menu surfaces show the ready state: runs always begin at
            // full health.
            return 1
        }
    }
}

/// A resource glyph that hollows out as it depletes: the outline is
/// always present, and the filled variant is masked to the remaining
/// fraction from the bottom up. The level reads as shape, not hue, so it
/// never rests on color alone.
private struct DrainingGlyph: View {
    let hollow: String
    let filled: String
    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Image(systemName: hollow)
                .foregroundStyle(.white.opacity(0.55))
            Image(systemName: filled)
                .foregroundStyle(tint)
                .mask {
                    GeometryReader { proxy in
                        Rectangle()
                            .frame(height: proxy.size.height * clampedFraction)
                            .offset(y: proxy.size.height * (1 - clampedFraction))
                    }
                }
        }
        .font(.subheadline.weight(.semibold))
    }

    private var clampedFraction: Double {
        max(0, min(1, fraction))
    }
}

/// Stamina in the battery's clothes: same silhouette and position as the
/// system gauge, filled with the player's color and draining as tokens
/// spend.
private struct StaminaBatteryGauge: View {
    let fraction: Double
    /// Optional count shown inside the case, the way iOS shows the
    /// battery percentage; the case stretches to fit it.
    var label: String? = nil

    var body: some View {
        HStack(spacing: 1) {
            ZStack {
                if let label {
                    Text(label)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .fixedSize()
                        .padding(.horizontal, 5)
                }
            }
            .frame(minWidth: 31, minHeight: 15)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            AFKRelayUIStyle.player
                                .opacity(label == nil ? 1 : 0.55)
                        )
                        .frame(
                            width: max(0, (proxy.size.width - 4) * clampedFraction),
                            height: proxy.size.height - 4
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4.5)
                    .stroke(.white.opacity(0.5), lineWidth: 1)
            }
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 2.5, height: 6)
        }
    }

    private var clampedFraction: Double {
        max(0, min(1, fraction))
    }
}
