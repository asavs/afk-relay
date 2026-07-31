import Foundation

/// A semantic visual role. Gameplay may select a role, but only a presentation
/// catalog decides how that role looks.
enum PresentationRole: String, CaseIterable, Sendable {
    case arenaBackground
    case arenaBoundary
    case playerBody
    case playerHurtbox
    case enemyBody
    case enemyHurtbox
    case attackTelegraph
    case attackActive
    case playerDamageImpact
    case friendlyFireImpact
    case intendedPath
    case resolvedPath
    case collisionNormal
    case pursuitVector
    case diagnosticText
}
