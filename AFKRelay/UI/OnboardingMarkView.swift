import SwiftUI

struct OnboardingMarkView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                .fill(AFKRelayUIStyle.panel)
            RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                .stroke(AFKRelayUIStyle.player, lineWidth: 2)
            Image(systemName: "shoeprints.fill")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(AFKRelayUIStyle.player)

            if differentiateWithoutColor {
                RoundedRectangle(cornerRadius: AFKRelayUIStyle.panelCornerRadius)
                    .inset(by: 8)
                    .stroke(
                        AFKRelayUIStyle.player,
                        style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                    )
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityHidden(true)
    }
}
