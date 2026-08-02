import Foundation

nonisolated struct MVPBalance: Equatable, Sendable {
    let arenaSize: Vector2; let playerRadius: Double; let playerSpeed: Double; let playerHitPoints: Int
    let movementDistancePerToken: Double; let enemyRadius: Double; let enemySpeed: Double; let tutorialEnemySpeed: Double; let enemyHitPoints: Int
    let sweepTriggerDistance: Double; let sweepReach: Double; let sweepArcDegrees: Double; let sweepBladeDegrees: Double
    let sweepTelegraphDuration: Double; let sweepActiveDuration: Double; let sweepRecoveryDuration: Double; let sweepDamage: Int
    let spawnInitialInterval: Double; let spawnMinimumInterval: Double; let spawnRampDuration: Double; let enemyCap: Int

    // ADR-0020: the ranged marksman and its linear shot. The shot's range
    // exceeds twice the standoff distance on purpose — a shot that misses the
    // player carries on across the ring and can reach the marksman opposite,
    // which is the counterplay that keeps shooters from accumulating.
    let shotTriggerDistance: Double
    let shotStandoffDistance: Double
    let shotStandoffBand: Double
    let shotRange: Double
    let shotSpeed: Double
    let shotRadius: Double
    let shotTelegraphDuration: Double
    let shotRecoveryDuration: Double
    let shotDamage: Int
    let marksmanRadius: Double
    let marksmanSpeed: Double
    let marksmanHitPoints: Int
    /// One in every this many endless spawns is a marksman.
    let marksmanSpawnPeriod: Int
    /// Living marksmen may never exceed this. Nothing the player does kills
    /// them directly, so an unbounded mix could fill the arena cap with
    /// shooters and leave a run with no counterplay.
    let marksmanCap: Int

    init(
        arenaSize: Vector2,
        playerRadius: Double,
        playerSpeed: Double,
        playerHitPoints: Int,
        movementDistancePerToken: Double,
        enemyRadius: Double,
        enemySpeed: Double,
        tutorialEnemySpeed: Double,
        enemyHitPoints: Int,
        sweepTriggerDistance: Double,
        sweepReach: Double,
        sweepArcDegrees: Double,
        sweepBladeDegrees: Double,
        sweepTelegraphDuration: Double,
        sweepActiveDuration: Double,
        sweepRecoveryDuration: Double,
        sweepDamage: Int,
        spawnInitialInterval: Double,
        spawnMinimumInterval: Double,
        spawnRampDuration: Double,
        enemyCap: Int,
        shotTriggerDistance: Double = 560,
        shotStandoffDistance: Double = 380,
        shotStandoffBand: Double = 45,
        shotRange: Double = 820,
        shotSpeed: Double = 560,
        shotRadius: Double = 14,
        shotTelegraphDuration: Double = 0.8,
        shotRecoveryDuration: Double = 0.9,
        shotDamage: Int = 1,
        marksmanRadius: Double = 30,
        marksmanSpeed: Double = 70,
        marksmanHitPoints: Int = 1,
        marksmanSpawnPeriod: Int = 3,
        marksmanCap: Int = 6
    ) {
        self.arenaSize = arenaSize
        self.playerRadius = playerRadius
        self.playerSpeed = playerSpeed
        self.playerHitPoints = playerHitPoints
        self.movementDistancePerToken = movementDistancePerToken
        self.enemyRadius = enemyRadius
        self.enemySpeed = enemySpeed
        self.tutorialEnemySpeed = tutorialEnemySpeed
        self.enemyHitPoints = enemyHitPoints
        self.sweepTriggerDistance = sweepTriggerDistance
        self.sweepReach = sweepReach
        self.sweepArcDegrees = sweepArcDegrees
        self.sweepBladeDegrees = sweepBladeDegrees
        self.sweepTelegraphDuration = sweepTelegraphDuration
        self.sweepActiveDuration = sweepActiveDuration
        self.sweepRecoveryDuration = sweepRecoveryDuration
        self.sweepDamage = sweepDamage
        self.spawnInitialInterval = spawnInitialInterval
        self.spawnMinimumInterval = spawnMinimumInterval
        self.spawnRampDuration = spawnRampDuration
        self.enemyCap = enemyCap
        self.shotTriggerDistance = shotTriggerDistance
        self.shotStandoffDistance = shotStandoffDistance
        self.shotStandoffBand = shotStandoffBand
        self.shotRange = shotRange
        self.shotSpeed = shotSpeed
        self.shotRadius = shotRadius
        self.shotTelegraphDuration = shotTelegraphDuration
        self.shotRecoveryDuration = shotRecoveryDuration
        self.shotDamage = shotDamage
        self.marksmanRadius = marksmanRadius
        self.marksmanSpeed = marksmanSpeed
        self.marksmanHitPoints = marksmanHitPoints
        self.marksmanSpawnPeriod = marksmanSpawnPeriod
        self.marksmanCap = marksmanCap
    }

    // ADR-0015/0016: v3 keeps the enlarged player and matches the arena
    // aspect to the display so the field fills the screen edge to edge.
    static let v3 = MVPBalance(arenaSize: .init(x: 640, y: 1400), playerRadius: 36, playerSpeed: 240, playerHitPoints: 3, movementDistancePerToken: 43.2, enemyRadius: 34, enemySpeed: 90, tutorialEnemySpeed: 75, enemyHitPoints: 2, sweepTriggerDistance: 200, sweepReach: 190, sweepArcDegrees: 120, sweepBladeDegrees: 28, sweepTelegraphDuration: 1, sweepActiveDuration: 0.45, sweepRecoveryDuration: 0.75, sweepDamage: 1, spawnInitialInterval: 4, spawnMinimumInterval: 1.5, spawnRampDuration: 180, enemyCap: 20)
}
