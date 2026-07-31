import SwiftUI

struct JoystickDirectionTicksView: View {
    let isEnabled: Bool

    var body: some View {
        ZStack {
            Capsule()
                .frame(width: 3, height: 112)
            Capsule()
                .frame(width: 112, height: 3)
        }
        .foregroundStyle(isEnabled ? .white.opacity(0.42) : .secondary)
        .accessibilityHidden(true)
    }
}
