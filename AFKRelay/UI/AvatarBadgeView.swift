import SwiftUI

/// The player's placeholder portrait, matching the arena's diagnostic mark.
/// Purely decorative and token-styled: production avatar art replaces this
/// view without touching any surrounding layout.
struct AvatarBadgeView: View {
    var isDefeated = false

    @ScaledMetric(relativeTo: .largeTitle) private var diameter = 96.0

    var body: some View {
        ZStack {
            Circle()
                .fill(isDefeated ? Color(white: 0.42) : AFKRelayUIStyle.player)
            Circle()
                .stroke(.white, lineWidth: 4)

            Group {
                Capsule()
                    .frame(width: 5, height: diameter * 0.44)
                Capsule()
                    .frame(width: diameter * 0.44, height: 5)
            }
            .foregroundStyle(.black)
            .rotationEffect(isDefeated ? .degrees(45) : .zero)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
