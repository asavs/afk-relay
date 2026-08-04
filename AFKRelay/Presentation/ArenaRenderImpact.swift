import CoreGraphics
import Foundation

struct ArenaRenderImpact: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case playerDamage
        case friendlyFire
    }

    let id: String
    let position: CGPoint
    let sourceEntityID: String
    let targetEntityID: String
    let kind: Kind
    /// The discovery moment: the first friendly-fire hit of a run's staged
    /// tutorial receives amplified presentation (REQ-GAME-007).
    var isEmphasized = false
}
