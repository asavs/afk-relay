import Foundation

struct MovementIntent: Equatable, Sendable {
    let x: Double
    let y: Double

    static let zero = MovementIntent(x: 0, y: 0)

    var magnitude: Double {
        hypot(x, y)
    }
}
