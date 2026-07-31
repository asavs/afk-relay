import SwiftUI

struct VirtualJoystickView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var intent = MovementIntent.zero

    let isEnabled: Bool
    let disabledAccessibilityValue: String
    let onIntentChanged: @MainActor (MovementIntent) -> Void

    private let diameter = 148.0
    private let knobDiameter = 62.0

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.5))
                .stroke(
                    isEnabled ? AFKRelayUIStyle.player : .secondary,
                    style: StrokeStyle(
                        lineWidth: 3,
                        dash: differentiateWithoutColor ? [8, 5] : []
                    )
                )

            JoystickDirectionTicksView(isEnabled: isEnabled)

            Circle()
                .fill(isEnabled ? AFKRelayUIStyle.player : .secondary)
                .stroke(.white, lineWidth: 3)
                .frame(width: knobDiameter, height: knobDiameter)
                .offset(knobOffset)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(.circle)
        .gesture(dragGesture)
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Movement joystick")
        .accessibilityValue(
            isEnabled ? "Ready" : disabledAccessibilityValue
        )
        .accessibilityHint("Drag in the direction you want to move.")
        .accessibilityAddTraits(isEnabled ? .allowsDirectInteraction : .isStaticText)
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                resetIntent()
            }
        }
        .onDisappear(perform: resetIntent)
        .accessibilityIdentifier("movement-joystick")
    }

    private var maximumKnobOffset: Double {
        (diameter - knobDiameter) / 2
    }

    private var knobOffset: CGSize {
        CGSize(
            width: intent.x * maximumKnobOffset,
            height: -intent.y * maximumKnobOffset
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged(updateIntent)
            .onEnded(endIntent)
    }

    private func updateIntent(_ value: DragGesture.Value) {
        guard isEnabled else {
            resetIntent()
            return
        }

        let center = diameter / 2
        let rawX = value.location.x - center
        let rawY = center - value.location.y
        let rawMagnitude = hypot(rawX, rawY)
        let scale = rawMagnitude > maximumKnobOffset
            ? maximumKnobOffset / rawMagnitude
            : 1
        let nextIntent = MovementIntent(
            x: rawX * scale / maximumKnobOffset,
            y: rawY * scale / maximumKnobOffset
        )

        intent = nextIntent
        onIntentChanged(nextIntent)
    }

    private func endIntent(_ value: DragGesture.Value) {
        resetIntent()
    }

    private func resetIntent() {
        if reduceMotion {
            intent = .zero
        } else {
            withAnimation(.snappy(duration: 0.18)) {
                intent = .zero
            }
        }
        onIntentChanged(.zero)
    }
}
