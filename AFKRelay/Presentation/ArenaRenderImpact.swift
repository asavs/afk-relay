import CoreGraphics
import Foundation

struct ArenaRenderImpact: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case playerDamage
        case friendlyFire
    }

    let id: String
    let position: CGPoint
    let kind: Kind
}
