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
    /// An enemy that attacks at range. A separate role rather than a variant
    /// of `enemyBody`, because the silhouette has to say which threat it is
    /// before it acts (`ADR-0020`).
    case enemyBodyRanged
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

/// A semantic sound moment. Gameplay supplies attack and impact state, while
/// the active presentation catalog decides whether that moment has a sound and
/// which resource represents it.
enum PresentationSoundRole: String, CaseIterable, Sendable {
    case lobbyMusic
    case buttonPress
    case gameOver
    case sweepTelegraph
    case sweepActive
    case shotTelegraph
    case shotActive
    case playerDamageImpact
    case friendlyFireImpact
    case friendlyFireDiscovery
    case friendlyFireDefeat
}
