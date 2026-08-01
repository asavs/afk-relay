import SwiftUI

struct JoystickDirectionTicksView: View {
    let isEnabled: Bool
    let span: Double

    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 3, height: span)
            Capsule()
                .frame(width: span, height: 3)
        }
        .foregroundStyle(isEnabled ? .white.opacity(0.42) : .secondary)
        .accessibilityHidden(true)
    }
}
