import Foundation
import Testing
@testable import AFKRelay

@Suite("Arena snapshot presentation adapter")
@MainActor
struct ArenaSnapshotPresentationAdapterTests {
    private static let tallHealthBalance = MVPBalance(
        arenaSize: .init(x: 1000, y: 1500),
        playerRadius: 30,
        playerSpeed: 240,
        playerHitPoints: 7,
        movementDistancePerToken: 43.2,
        enemyRadius: 34,
        enemySpeed: 90,
        tutorialEnemySpeed: 75,
        enemyHitPoints: 5,
        sweepTriggerDistance: 200,
        sweepReach: 190,
        sweepArcDegrees: 120,
        sweepBladeDegrees: 28,
        sweepTelegraphDuration: 1,
        sweepActiveDuration: 0.45,
        sweepRecoveryDuration: 0.75,
        sweepDamage: 1,
        spawnInitialInterval: 4,
        spawnMinimumInterval: 1.5,
        spawnRampDuration: 180,
        enemyCap: 20
    )

    /// Endless from the first tick, with every spawn a marksman standing far
    /// enough away to aim rather than close.
    private static let marksmanBalance = MVPBalance(
        arenaSize: .init(x: 800, y: 800),
        playerRadius: 30,
        playerSpeed: 240,
        playerHitPoints: 3,
        movementDistancePerToken: 43.2,
        enemyRadius: 20,
        enemySpeed: 0,
        tutorialEnemySpeed: 0,
        enemyHitPoints: 2,
        sweepTriggerDistance: 0,
        sweepReach: 190,
        sweepArcDegrees: 120,
        sweepBladeDegrees: 28,
        sweepTelegraphDuration: 1,
        sweepActiveDuration: 0.45,
        sweepRecoveryDuration: 0.75,
        sweepDamage: 1,
        spawnInitialInterval: 4,
        spawnMinimumInterval: 1.5,
        spawnRampDuration: 180,
        enemyCap: 20,
        shotTriggerDistance: 900,
        marksmanRadius: 20,
        marksmanSpeed: 0,
        marksmanSpawnPeriod: 1
    )

    @Test("Entity health maxima follow the supplied balance")
    func healthMaximaFollowBalance() {
        let balance = Self.tallHealthBalance
        let simulation = ArenaSimulation(balance: balance)

        let rendered = ArenaSnapshotPresentationAdapter.makeSnapshot(
            from: simulation.snapshot,
            balance: balance
        )

        let player = rendered.entities.first { $0.role == .playerBody }
        let enemies = rendered.entities.filter { $0.role == .enemyBody }
        #expect(player?.maximumHitPoints == balance.playerHitPoints)
        #expect(!enemies.isEmpty)
        #expect(enemies.allSatisfy {
            $0.maximumHitPoints == balance.enemyHitPoints
        })
    }

    @Test("A ranged body carries its own role, health maximum, and lane")
    func rangedBodiesAndShots() throws {
        let balance = Self.marksmanBalance
        var simulation = ArenaSimulation(
            balance: balance,
            tutorialCompleted: true
        )
        for _ in 0..<120 where simulation.attacks.isEmpty {
            _ = simulation.step()
        }

        let rendered = ArenaSnapshotPresentationAdapter.makeSnapshot(
            from: simulation.snapshot,
            balance: balance
        )

        let marksman = try #require(
            rendered.entities.first { $0.role == .enemyBodyRanged }
        )
        #expect(marksman.maximumHitPoints == balance.marksmanHitPoints)

        let attack = try #require(rendered.attacks.first)
        guard case let .shot(shot) = attack.shape else {
            Issue.record("A marksman must render a shot, not \(attack.shape)")
            return
        }
        #expect(Double(attack.reach) == balance.shotRange)
        #expect(Double(shot.halfWidth) == balance.shotRadius)
        // Nothing has left the muzzle while the lane is still a warning.
        #expect(attack.phase == .telegraph)
        #expect(shot.noseDistance == 0)
        #expect(shot.isBlocked == false)
    }

    @Test("Diagnostics report the authoritative fixed-step rate")
    func diagnosticsFixedStepRate() {
        let simulation = ArenaSimulation()

        let rendered = ArenaSnapshotPresentationAdapter.makeSnapshot(
            from: simulation.snapshot
        )

        let expectedHz = Int((1 / ArenaSimulation.fixedTimeStep).rounded())
        #expect(rendered.diagnostics?.fixedStepHz == expectedHz)
    }
}
