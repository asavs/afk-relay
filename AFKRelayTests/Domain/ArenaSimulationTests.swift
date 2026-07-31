import Foundation
import Testing
@testable import AFKRelay

@Suite("Deterministic arena")
struct ArenaSimulationTests {
    @Test("Initial tutorial contains one slow enemy and no player attack")
    func initial() {
        let arena = ArenaSimulation()
        #expect(arena.enemies.count == 1)
        #expect(arena.attacks.isEmpty)
        #expect(arena.tutorialStage == .moveAndEvade)
    }

    @Test(arguments: [30, 60, 120])
    func renderSchedulesAgree(fps: Int) {
        var reference = ArenaSimulation()
        var scheduled = ArenaSimulation()
        var referenceEvents: [GameEvent] = []
        var scheduledEvents: [GameEvent] = []
        var referenceEconomy = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 10_000
        )
        var scheduledEconomy = referenceEconomy
        let seconds = 15
        let fixedTicks = seconds * 60

        for _ in 0..<fixedTicks {
            referenceEvents += reference.step(input: .init(x: 1, y: 0.2))
            _ = MovementCostPolicy.commit(
                distance: reference.lastPlayerTravelDistance,
                state: &referenceEconomy
            )
        }

        var dispatchedTicks = 0
        for renderedFrame in 1...(fps * seconds) {
            let targetTicks = Int(
                (Double(renderedFrame) * 60 / Double(fps)).rounded(.down)
            )
            while dispatchedTicks < targetTicks {
                scheduledEvents += scheduled.step(
                    input: .init(x: 1, y: 0.2)
                )
                _ = MovementCostPolicy.commit(
                    distance: scheduled.lastPlayerTravelDistance,
                    state: &scheduledEconomy
                )
                dispatchedTicks += 1
            }
        }

        #expect(dispatchedTicks == fixedTicks)
        #expect(reference.snapshot == scheduled.snapshot)
        #expect(referenceEvents == scheduledEvents)
        #expect(referenceEconomy == scheduledEconomy)
    }

    @Test("Bounds block movement without pushing bodies")
    func bounds() {
        var arena = ArenaSimulation()
        for _ in 0..<500 { _ = arena.step(input: .init(x: -1, y: -1)) }
        #expect(arena.player.position.x >= MVPBalance.v1.playerRadius)
        #expect(arena.player.position.y >= MVPBalance.v1.playerRadius)
    }

    @Test("New attacks expose a full telegraph beginning at age zero")
    func phases() {
        var arena = ArenaSimulation(balance: compactTutorialBalance())

        _ = arena.step()

        let attack = arena.attacks.first
        #expect(attack?.age == 0)
        #expect(
            attack.map {
                SweepGeometry.phase(
                    at: $0.age,
                    balance: arena.balance
                )
            } == .telegraph(progress: 0)
        )
        #expect(!arena.enemies.isEmpty)
        #expect(arena.enemies.allSatisfy { $0.velocity == .zero })
    }

    @Test("Movement plus an avoided full telegraph advances to two-enemy staging")
    func tutorialEvasion() {
        var arena = ArenaSimulation(balance: compactTutorialBalance())
        var events: [GameEvent] = []

        for _ in 0..<180 where arena.tutorialStage == .moveAndEvade {
            events += arena.step(input: Vector2(x: 1, y: 0))
        }

        #expect(arena.tutorialStage == .friendlyFire)
        #expect(arena.enemies.count == 2)
        #expect(events.contains(.tutorialAdvanced(.friendlyFire)))
    }

    @Test("Completed tutorial launches directly into endless pressure")
    func completedTutorialSkip() {
        let arena = ArenaSimulation(tutorialCompleted: true)
        #expect(arena.tutorialStage == .endless)
        #expect(arena.enemies.count == 1)
    }

    @Test("Endless pressure ramps from four to one-and-a-half seconds")
    func spawnRamp() {
        let balance = MVPBalance.v1
        #expect(
            EndlessPressurePolicy.spawnInterval(
                at: 0,
                balance: balance
            ) == 4
        )
        #expect(
            EndlessPressurePolicy.spawnInterval(
                at: 90,
                balance: balance
            ) == 2.75
        )
        #expect(
            EndlessPressurePolicy.spawnInterval(
                at: 180,
                balance: balance
            ) == 1.5
        )
        #expect(
            EndlessPressurePolicy.spawnInterval(
                at: 1_000,
                balance: balance
            ) == 1.5
        )
    }

    @Test("Enemy cap retains at most one pending spawn interval")
    func spawnCapDiscardsBacklog() {
        let balance = MVPBalance.v1
        var scheduler = EndlessSpawnScheduler()

        for _ in 0..<(60 * 30) {
            let shouldSpawn = scheduler.advance(
                duration: ArenaSimulation.fixedTimeStep,
                livingEnemyCount: balance.enemyCap,
                balance: balance
            )
            #expect(shouldSpawn == false)
        }

        let intervalAtCapacity = EndlessPressurePolicy.spawnInterval(
            at: scheduler.elapsed,
            balance: balance
        )
        #expect(scheduler.pendingTime <= intervalAtCapacity)
        let firstRelease = scheduler.advance(
            duration: ArenaSimulation.fixedTimeStep,
            livingEnemyCount: balance.enemyCap - 1,
            balance: balance
        )
        #expect(firstRelease)
        let nextTick = scheduler.advance(
            duration: ArenaSimulation.fixedTimeStep,
            livingEnemyCount: balance.enemyCap - 2,
            balance: balance
        )
        #expect(nextTick == false)
    }

    @Test("Friendly-fire discovery requires a living player")
    func lethalFriendlyFireDoesNotCompleteTutorial() {
        let friendlyFire = GameEvent.damaged(
            target: 2,
            source: 1,
            amount: 1,
            position: Vector2(x: 100, y: 100)
        )
        let playerDamage = GameEvent.damaged(
            target: 0,
            source: 1,
            amount: 1,
            position: Vector2(x: 120, y: 100)
        )

        #expect(
            ArenaTutorialPolicy.shouldCompleteFriendlyFireStage(
                playerHitPoints: 1,
                playerID: 0,
                events: [friendlyFire]
            )
        )
        #expect(
            ArenaTutorialPolicy.shouldCompleteFriendlyFireStage(
                playerHitPoints: 0,
                playerID: 0,
                events: [friendlyFire]
            ) == false
        )
        #expect(
            ArenaTutorialPolicy.shouldCompleteFriendlyFireStage(
                playerHitPoints: 1,
                playerID: 0,
                events: [playerDamage]
            ) == false
        )
    }

    @Test("Authoritative friendly fire wounds, completes staging, and defeats")
    func authoritativeFriendlyFire() throws {
        let balance = friendlyFireIntegrationBalance()
        var arena = ArenaSimulation(balance: balance)
        var tutorialEvents: [GameEvent] = []

        // Move to a known point outside the first 60-degree sweep. The first
        // enemy remains fixed, so completing its attack proves actual evasion.
        for tick in 0..<300 where arena.tutorialStage == .moveAndEvade {
            let input = tick < 43
                ? Vector2(x: 1, y: -0.714_285_714)
                : .zero
            tutorialEvents += arena.step(input: input)
        }

        #expect(arena.tutorialStage == .friendlyFire)
        #expect(arena.enemies.count == 2)

        var friendlyFireEvents: [GameEvent] = []
        for _ in 0..<300 where arena.tutorialStage == .friendlyFire {
            friendlyFireEvents += arena.step()
        }

        #expect(arena.tutorialStage == .endless)
        #expect(friendlyFireEvents.contains(.tutorialCompleted))
        let firstFriendlyFireDamage = try #require(
            friendlyFireEvents.first { event in
                guard case let .damaged(target, source, _, _) = event else {
                    return false
                }
                return target != arena.player.id && target != source
            }
        )
        guard case let .damaged(woundedID, sourceID, amount, _) =
            firstFriendlyFireDamage
        else {
            Issue.record("Expected an authoritative enemy damage event.")
            return
        }
        #expect(amount == balance.sweepDamage)
        #expect(woundedID != sourceID)
        #expect(
            arena.enemies.first(where: { $0.id == woundedID })?.hitPoints
                == balance.enemyHitPoints - balance.sweepDamage
        )

        var defeatEvents: [GameEvent] = []
        for _ in 0..<300
            where defeatEvents.contains(.enemyDefeated(woundedID)) == false
        {
            defeatEvents += arena.step()
        }

        #expect(defeatEvents.contains(.enemyDefeated(woundedID)))
        #expect(arena.enemies.contains(where: { $0.id == woundedID }) == false)
        #expect(tutorialEvents.contains(.tutorialAdvanced(.friendlyFire)))
    }

    @Test("Authoritative endless spawning observes cadence, edge entry, cap, and HP")
    func authoritativeEndlessSpawning() throws {
        let balance = fastEndlessIntegrationBalance()
        var arena = ArenaSimulation(
            balance: balance,
            tutorialCompleted: true
        )
        var spawnTimes: [Double] = []
        var spawnPositions: [Vector2] = []
        var maximumLivingEnemies = arena.enemies.count

        for _ in 0..<(5 * 60) {
            let events = arena.step()
            maximumLivingEnemies = max(maximumLivingEnemies, arena.enemies.count)

            for event in events {
                guard case let .spawned(id) = event else { continue }
                let enemy = try #require(
                    arena.enemies.first(where: { $0.id == id })
                )
                spawnTimes.append(arena.elapsed)
                spawnPositions.append(enemy.position)
            }
        }

        #expect(arena.enemies.count == balance.enemyCap)
        #expect(maximumLivingEnemies == balance.enemyCap)
        #expect(spawnTimes.count == balance.enemyCap - 1)
        #expect(
            arena.enemies.allSatisfy {
                $0.hitPoints == balance.enemyHitPoints
            }
        )
        #expect(
            zip(spawnTimes, spawnTimes.dropFirst()).allSatisfy {
                pair in
                pair.1 - pair.0
                    >= balance.spawnMinimumInterval - 0.000_001
            }
        )
        #expect(
            spawnPositions.allSatisfy { position in
                let onVerticalEdge =
                    abs(position.x - balance.enemyRadius) < 0.000_001
                    || abs(
                        position.x
                            - (balance.arenaSize.x - balance.enemyRadius)
                    ) < 0.000_001
                let onHorizontalEdge =
                    abs(position.y - balance.enemyRadius) < 0.000_001
                    || abs(
                        position.y
                            - (balance.arenaSize.y - balance.enemyRadius)
                    ) < 0.000_001
                return onVerticalEdge || onHorizontalEdge
            }
        )
    }

    @Test("Reset before completion restarts the discovery sequence")
    func deathStyleReset() {
        var arena = ArenaSimulation(tutorialCompleted: true)
        arena.reset(tutorialCompleted: false)
        #expect(arena.tutorialStage == .moveAndEvade)
        #expect(arena.enemies.count == 1)
        #expect(arena.player.hitPoints == MVPBalance.v1.playerHitPoints)
    }

    @Test("Authoritative run result includes movement spent on the lethal tick")
    func lethalTickSpend() {
        var arena = ArenaSimulation(
            balance: compactTutorialBalance(playerHitPoints: 1),
            tutorialCompleted: true
        )
        var economy = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 1_000
        )

        for _ in 0..<300 where arena.result == nil {
            _ = arena.step(input: Vector2(x: -0.2, y: -0.2))
            let before = economy.lifetimeTokensSpent
            _ = MovementCostPolicy.commit(
                distance: arena.lastPlayerTravelDistance,
                state: &economy
            )
            arena.recordMovementTokensSpent(
                economy.lifetimeTokensSpent - before
            )
        }

        #expect(arena.result != nil)
        #expect(economy.lifetimeTokensSpent > 0)
        #expect(arena.result?.tokensSpent == economy.lifetimeTokensSpent)
    }

    @Test("A post-result tick reports zero resolved movement")
    func finishedSimulationClearsMovementDistance() throws {
        var arena = ArenaSimulation(
            balance: compactTutorialBalance(playerHitPoints: 1),
            tutorialCompleted: true
        )

        for _ in 0..<180 where arena.result == nil {
            _ = arena.step(input: Vector2(x: 0.05, y: -0.05))
        }

        try #require(arena.result != nil)
        try #require(arena.lastPlayerTravelDistance > 0)

        let events = arena.step(input: Vector2(x: 1, y: 0))

        #expect(events.isEmpty)
        #expect(arena.lastPlayerTravelDistance == 0)
        #expect(arena.lastPlayerCollisionNormals.isEmpty)
    }

    private func compactTutorialBalance(
        playerHitPoints: Int = 3
    ) -> MVPBalance {
        MVPBalance(
            arenaSize: Vector2(x: 300, y: 300),
            playerRadius: 10,
            playerSpeed: 240,
            playerHitPoints: playerHitPoints,
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
            enemyCap: 20
        )
    }

    private func friendlyFireIntegrationBalance() -> MVPBalance {
        MVPBalance(
            arenaSize: Vector2(x: 300, y: 300),
            playerRadius: 10,
            playerSpeed: 240,
            playerHitPoints: 100,
            movementDistancePerToken: 43.2,
            enemyRadius: 10,
            enemySpeed: 0,
            tutorialEnemySpeed: 0,
            enemyHitPoints: 2,
            sweepTriggerDistance: 500,
            sweepReach: 500,
            sweepArcDegrees: 60,
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
    }

    private func fastEndlessIntegrationBalance() -> MVPBalance {
        MVPBalance(
            arenaSize: Vector2(x: 1_000, y: 1_500),
            playerRadius: 5,
            playerSpeed: 240,
            playerHitPoints: 3,
            movementDistancePerToken: 43.2,
            enemyRadius: 5,
            enemySpeed: 200,
            tutorialEnemySpeed: 75,
            enemyHitPoints: 2,
            sweepTriggerDistance: 0,
            sweepReach: 0,
            sweepArcDegrees: 120,
            sweepBladeDegrees: 28,
            sweepTelegraphDuration: 1,
            sweepActiveDuration: 0.45,
            sweepRecoveryDuration: 0.75,
            sweepDamage: 1,
            spawnInitialInterval: 0.1,
            spawnMinimumInterval: 0.1,
            spawnRampDuration: 180,
            enemyCap: 20
        )
    }
}
