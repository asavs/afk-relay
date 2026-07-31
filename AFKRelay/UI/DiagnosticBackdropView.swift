import SwiftUI

struct DiagnosticBackdropView: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(AFKRelayUIStyle.background)
            )

            let step = 32.0
            var grid = Path()

            for x in stride(from: 0.0, through: size.width, by: step) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: step) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(
                grid,
                with: .color(.white.opacity(contrast == .increased ? 0.16 : 0.07)),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
        .accessibilityHidden(true)
    }
}
