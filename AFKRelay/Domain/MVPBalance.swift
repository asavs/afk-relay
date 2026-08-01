import Foundation

nonisolated struct MVPBalance: Equatable, Sendable {
    let arenaSize: Vector2; let playerRadius: Double; let playerSpeed: Double; let playerHitPoints: Int
    let movementDistancePerToken: Double; let enemyRadius: Double; let enemySpeed: Double; let tutorialEnemySpeed: Double; let enemyHitPoints: Int
    let sweepTriggerDistance: Double; let sweepReach: Double; let sweepArcDegrees: Double; let sweepBladeDegrees: Double
    let sweepTelegraphDuration: Double; let sweepActiveDuration: Double; let sweepRecoveryDuration: Double; let sweepDamage: Int
    let spawnInitialInterval: Double; let spawnMinimumInterval: Double; let spawnRampDuration: Double; let enemyCap: Int
    // ADR-0015/0016: v3 keeps the enlarged player and matches the arena
    // aspect to the display so the field fills the screen edge to edge.
    static let v3 = MVPBalance(arenaSize: .init(x: 640, y: 1400), playerRadius: 36, playerSpeed: 240, playerHitPoints: 3, movementDistancePerToken: 43.2, enemyRadius: 34, enemySpeed: 90, tutorialEnemySpeed: 75, enemyHitPoints: 2, sweepTriggerDistance: 200, sweepReach: 190, sweepArcDegrees: 120, sweepBladeDegrees: 28, sweepTelegraphDuration: 1, sweepActiveDuration: 0.45, sweepRecoveryDuration: 0.75, sweepDamage: 1, spawnInitialInterval: 4, spawnMinimumInterval: 1.5, spawnRampDuration: 180, enemyCap: 20)
}
