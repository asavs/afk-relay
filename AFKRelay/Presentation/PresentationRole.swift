import Foundation

/// A semantic visual role. Gameplay may select a role, but only a presentation
/// catalog decides how that role looks.
enum PresentationRole: String, CaseIterable, Sendable {
    case arenaBackground
    case arenaBoundary
    case playerBody
    case playerHurtbox
    case enemyBody
    /// An enemy that has taken damage but still lives. A damage *state*,
    /// not an asset: future catalogs may render limping bodies or broken
    /// armor; the diagnostic catalog renders a wounded tint and crack.
    case enemyBodyWounded
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
