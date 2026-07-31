import SwiftUI

struct OnboardingMarkView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack {
            Circle()
                .fill(AFKRelayUIStyle.player)
            Circle()
                .stroke(.white, lineWidth: 4)
            Image(systemName: "shoeprints.fill")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.black)

            if differentiateWithoutColor {
                Circle()
                    .inset(by: 10)
                    .stroke(.black, style: StrokeStyle(lineWidth: 3, dash: [5, 4]))
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityHidden(true)
    }
}
