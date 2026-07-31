import CoreGraphics
import Foundation

struct ArenaRenderVector: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case intendedPath
        case resolvedPath
        case collisionNormal
        case pursuit
    }

    let id: String
    let start: CGPoint
    let end: CGPoint
    let kind: Kind
}
