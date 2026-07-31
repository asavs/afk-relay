import Foundation

struct ArenaAccessibilityOptions: Equatable, Sendable {
    var reduceMotion: Bool
    var differentiateWithoutColor: Bool
    var increaseContrast: Bool

    static let standard = ArenaAccessibilityOptions(
        reduceMotion: false,
        differentiateWithoutColor: false,
        increaseContrast: false
    )
}
