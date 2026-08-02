import Foundation
import Testing
@testable import AFKRelay

@Suite("Ranged enemy")
struct RangedEnemyTests {
    @Test("First-run staging fields only melee bodies")
    func stagingIsChevronsOnly() {
        var arena = ArenaSimulation(balance: stagingBalance())

        for _ in 0..<600 where arena.tutorialStage != .endless {
            _ = arena.step(input: Vector2(x: 1, y: 0))
        }

        #expect(arena.tutorialStage == .endless)
        #expect(arena.enemies.count >= 2)
        #expect(arena.enemies.allSatisfy { $0.archetype == .chevron })
    }

    @Test("Every third endless spawn is a marksman")
    func spawnMixIsCounted() {
        var arena = ArenaSimulation(
            balance: quietEndlessBalance(),
            tutorialCompleted: true
        )

        // The first spawn happens in the initialiser, so three enemies means
        // three endless spawns.
        for _ in 0..<600 where arena.enemies.count < 3 {
            _ = arena.step()
        }

        #expect(arena.enemies.map(\.archetype) == [.chevron, .chevron, .marksman])
    }

    @Test("Living marksmen never exceed their cap")
    func marksmanCapHolds() {
        var arena = ArenaSimulation(
            balance: quietEndlessBalance(
                marksmanSpawnPeriod: 1,
                marksmanCap: 2
            ),
            tutorialCompleted: true
        )

        // Nothing moves here, so the four edge-entry points are the ceiling.
        // Two of them fill with marksmen and the cap sends the rest melee.
        for _ in 0..<600 where arena.enemies.count < 4 {
            _ = arena.step()
        }

        #expect(arena.enemies.count == 4)
        #expect(arena.enemies.count { $0.archetype == .marksman } == 2)
    }

    @Test("A marksman closes to its standoff distance and holds there")
    func marksmanHoldsStandoff() {
        let balance = quietEndlessBalance(
            arenaSize: Vector2(x: 1_200, y: 1_200),
            marksmanSpawnPeriod: 1,
            marksmanSpeed: 200
        )
        var arena = ArenaSimulation(balance: balance, tutorialCompleted: true)
        let start = try? #require(arena.enemies.first)

        #expect(start?.archetype == .marksman)
        #expect(
            (start?.position.distance(to: arena.player.position) ?? 0)
                > balance.shotStandoffDistance
        )

        for _ in 0..<(60 * 6) {
            _ = arena.step()
        }

        let marksman = arena.enemies.first { $0.archetype == .marksman }
        let distance = marksman?.position.distance(to: arena.player.position) ?? 0
        // It settles inside the band it holds, and never walks into melee.
        #expect(distance > balance.shotStandoffDistance - balance.shotStandoffBand - 1)
        #expect(distance < balance.shotStandoffDistance + balance.shotStandoffBand + 1)
    }

    /// The whole point of a shot that stops at the first body: dodging does
    /// not make the shot go away, it makes the shot somebody else's problem.
    @Test("A dodged shot carries on down its lane into the body behind")
    func dodgedShotHitsTheBodyBehind() throws {
        var arena = ArenaSimulation(
            balance: crossfireBalance(),
            tutorialCompleted: true
        )

        // Stand still until the marksman spawns opposite and aims here.
        var ticksBeforeFiring = 0
        for _ in 0..<300 where !arena.attacks.contains(where: { $0.kind == .shot }) {
            _ = arena.step()
            ticksBeforeFiring += 1
        }
        let shot = try #require(arena.attacks.first { $0.kind == .shot })
        let marksman = try #require(
            arena.enemies.first { $0.archetype == .marksman }
        )
        let shielded = try #require(
            arena.enemies.first { $0.archetype == .chevron }
        )
        #expect(shot.sourceID == marksman.id)
        #expect(shot.origin == marksman.position)

        // Step out of the lane during the telegraph, then stand still again.
        // The window stops short of the marksman's next shot — 140 ticks is
        // past this bolt landing and before the following one is even thrown,
        // so the damage counted below belongs to exactly one shot.
        var events: [GameEvent] = []
        for tick in 0..<140 {
            let dodge = tick < 20 ? Vector2(x: 1, y: -1) : .zero
            events += arena.step(input: dodge)
        }

        let damage = events.compactMap { event -> (Int, Int)? in
            guard case let .damaged(target, source, _, _) = event else {
                return nil
            }
            return (target, source)
        }

        #expect(arena.player.hitPoints == arena.balance.playerHitPoints)
        #expect(damage.count == 1)
        #expect(damage.first?.0 == shielded.id)
        #expect(damage.first?.1 == marksman.id)
    }

    private func stagingBalance() -> MVPBalance {
        MVPBalance(
            arenaSize: Vector2(x: 300, y: 300),
            playerRadius: 10,
            playerSpeed: 240,
            playerHitPoints: 3,
            movementDistancePerToken: 43.2,
            enemyRadius: 10,
            enemySpeed: 90,
            tutorialEnemySpeed: 75,
            enemyHitPoints: 2,
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
            enemyCap: 20,
            marksmanSpawnPeriod: 1
        )
    }

    /// Endless pressure with nothing that attacks and nothing that moves, so
    /// only the spawn mix is under test.
    private func quietEndlessBalance(
        arenaSize: Vector2 = Vector2(x: 600, y: 600),
        marksmanSpawnPeriod: Int = 3,
        marksmanCap: Int = 6,
        marksmanSpeed: Double = 0
    ) -> MVPBalance {
        MVPBalance(
            arenaSize: arenaSize,
            playerRadius: 10,
            playerSpeed: 240,
            playerHitPoints: 3,
            movementDistancePerToken: 43.2,
            enemyRadius: 10,
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
            spawnInitialInterval: 0.1,
            spawnMinimumInterval: 0.1,
            spawnRampDuration: 180,
            enemyCap: 20,
            shotTriggerDistance: 0,
            marksmanRadius: 10,
            marksmanSpeed: marksmanSpeed,
            marksmanSpawnPeriod: marksmanSpawnPeriod,
            marksmanCap: marksmanCap
        )
    }

    /// A 560-square arena whose corner spawns put the player exactly between
    /// a marksman and a chevron on the same diagonal: the third endless spawn
    /// is the marksman, and the first sits 764 points beyond the player on
    /// the line it fires down.
    private func crossfireBalance() -> MVPBalance {
        MVPBalance(
            arenaSize: Vector2(x: 560, y: 560),
            playerRadius: 10,
            playerSpeed: 240,
            playerHitPoints: 3,
            movementDistancePerToken: 43.2,
            enemyRadius: 10,
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
            spawnInitialInterval: 0.1,
            spawnMinimumInterval: 0.1,
            spawnRampDuration: 180,
            enemyCap: 20,
            shotTriggerDistance: 600,
            marksmanRadius: 10,
            marksmanSpeed: 0
        )
    }
}
