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
