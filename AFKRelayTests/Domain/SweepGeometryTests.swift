import Foundation
import Testing
@testable import AFKRelay

@Suite("Rotating analytic sweep")
struct SweepGeometryTests {
    @Test("Phase boundaries are exact")
    func phaseBoundaries() {
        let balance = MVPBalance.v3

        #expect(SweepGeometry.phase(at: 0) == .telegraph(progress: 0))
        #expect(
            SweepGeometry.phase(at: balance.sweepTelegraphDuration)
                == .active(progress: 0)
        )
        #expect(
            SweepGeometry.phase(
                at: balance.sweepTelegraphDuration + balance.sweepActiveDuration
            ) == .recovery(progress: 0)
        )
        #expect(
            SweepGeometry.phase(
                at: balance.sweepTelegraphDuration
                    + balance.sweepActiveDuration
                    + balance.sweepRecoveryDuration
            ) == .finished
        )
    }

    @Test("Twenty-eight degree blade traverses the full 120 degree telegraph")
    func bladeTraversal() {
        let balance = MVPBalance.v3
        let facing = Vector2(x: 1, y: 0)
        let first = SweepGeometry.activeBladeAngles(
            facing: facing,
            age: balance.sweepTelegraphDuration,
            balance: balance
        )
        let last = SweepGeometry.activeBladeAngles(
            facing: facing,
            age: balance.sweepTelegraphDuration + balance.sweepActiveDuration,
            balance: balance
        )

        #expect(abs((first.upperBound - first.lowerBound) * 180 / .pi - 28) < 0.000_001)
        #expect(abs(first.lowerBound * 180 / .pi - -60) < 0.000_001)
        #expect(abs(last.upperBound * 180 / .pi - 60) < 0.000_001)
    }

    @Test("Angle wrapping and target radius use filled-sector geometry")
    func wrappingAndEdges() {
        let balance = MVPBalance.v3
        let middleOfActive = balance.sweepTelegraphDuration
            + balance.sweepActiveDuration / 2
        let wrappedTarget = Vector2(
            x: cos(-.pi + 0.01) * 100,
            y: sin(-.pi + 0.01) * 100
        )

        #expect(
            SweepGeometry.contains(
                targetCenter: wrappedTarget,
                targetRadius: 1,
                sourceCenter: .zero,
                facing: Vector2(x: -1, y: 0),
                age: middleOfActive,
                balance: balance
            )
        )
        #expect(
            SweepGeometry.contains(
                targetCenter: Vector2(x: 220, y: 0),
                targetRadius: 30,
                sourceCenter: .zero,
                facing: Vector2(x: 1, y: 0),
                age: middleOfActive,
                balance: balance
            )
        )
        #expect(
            !SweepGeometry.contains(
                targetCenter: Vector2(x: 220.1, y: 0),
                targetRadius: 30,
                sourceCenter: .zero,
                facing: Vector2(x: 1, y: 0),
                age: middleOfActive,
                balance: balance
            )
        )
    }

    @Test("Finite-sector corners do not over-include a circular hurtbox")
    func finiteSectorCorner() {
        let angle = 22.0 * Double.pi / 180
        let target = Vector2(
            x: cos(angle) * 210,
            y: sin(angle) * 210
        )
        let middleOfActive = MVPBalance.v3.sweepTelegraphDuration
            + MVPBalance.v3.sweepActiveDuration / 2

        #expect(
            !SweepGeometry.contains(
                targetCenter: target,
                targetRadius: 30,
                sourceCenter: .zero,
                facing: Vector2(x: 1, y: 0),
                age: middleOfActive,
                balance: .v3
            )
        )
    }

    @Test("The final advertised blade endpoint is included in swept evaluation")
    func finalSweptEndpoint() {
        let balance = MVPBalance.v3
        let activeEnd = balance.sweepTelegraphDuration
            + balance.sweepActiveDuration
        let targetAngle = 59.0 * Double.pi / 180
        let target = Vector2(
            x: cos(targetAngle) * 120,
            y: sin(targetAngle) * 120
        )

        #expect(
            SweepGeometry.containsSwept(
                targetCenter: target,
                targetRadius: 1,
                sourceCenter: .zero,
                facing: Vector2(x: 1, y: 0),
                fromAge: activeEnd - ArenaSimulation.fixedTimeStep,
                throughAge: activeEnd,
                balance: balance
            )
        )
    }

    @Test("Resolver is source-immune, ordered, multi-target, and one-hit")
    func targetResolution() {
        let balance = MVPBalance.v3
        let age = balance.sweepTelegraphDuration
            + balance.sweepActiveDuration / 2
        let source = entity(id: 9, position: .zero)
        let attack = ArenaAttack(
            sourceID: source.id,
            facing: Vector2(x: 1, y: 0),
            age: age,
            playerTravelDistance: 0,
            hitIDs: [2]
        )
        let targets = [
            entity(id: 9, position: .zero),
            entity(id: 5, position: Vector2(x: 120, y: 0)),
            entity(id: 2, position: Vector2(x: 100, y: 0)),
            entity(id: 0, position: Vector2(x: 80, y: 0), isPlayer: true),
        ]

        let hitIDs = ArenaAttackResolver.eligibleTargetIDs(
            for: attack,
            source: source,
            targets: targets,
            balance: balance
        )

        #expect(hitIDs == [0, 5])
    }

    private func entity(
        id: Int,
        position: Vector2,
        isPlayer: Bool = false
    ) -> ArenaEntity {
        ArenaEntity(
            id: id,
            position: position,
            velocity: .zero,
            facing: Vector2(x: 1, y: 0),
            radius: isPlayer
                ? MVPBalance.v3.playerRadius
                : MVPBalance.v3.enemyRadius,
            hitPoints: isPlayer
                ? MVPBalance.v3.playerHitPoints
                : MVPBalance.v3.enemyHitPoints,
            isPlayer: isPlayer
        )
    }
}

@Suite("Sweep direction")
struct SweepDirectionTests {
    @Test("A reversed blade starts where a forward one finishes")
    func reversedStartsAtFarEdge() {
        let balance = MVPBalance.v3
        let facing = Vector2(x: 1, y: 0)
        let activeStart = balance.sweepTelegraphDuration
        let activeEnd = activeStart + balance.sweepActiveDuration

        let forwardStart = SweepGeometry.activeBladeAngles(
            facing: facing,
            age: activeStart,
            reversed: false,
            balance: balance
        )
        let reversedEnd = SweepGeometry.activeBladeAngles(
            facing: facing,
            age: activeEnd,
            reversed: true,
            balance: balance
        )
        #expect(abs(forwardStart.lowerBound - reversedEnd.lowerBound) < 0.000_001)

        let forwardEnd = SweepGeometry.activeBladeAngles(
            facing: facing,
            age: activeEnd,
            reversed: false,
            balance: balance
        )
        let reversedStart = SweepGeometry.activeBladeAngles(
            facing: facing,
            age: activeStart,
            reversed: true,
            balance: balance
        )
        #expect(abs(forwardEnd.upperBound - reversedStart.upperBound) < 0.000_001)
    }

    /// The direction has to change what the swing hits, or it is decoration.
    @Test("Direction decides who is caught early in the swing")
    func directionChangesEarlyHits() {
        let balance = MVPBalance.v3
        let source = Vector2(x: 0, y: 0)
        let facing = Vector2(x: 1, y: 0)
        let earlyAge = balance.sweepTelegraphDuration + 0.02

        // Two targets parked at opposite edges of the arc.
        let halfArc = balance.sweepArcDegrees / 2 * .pi / 180
        let radius = balance.sweepReach * 0.6
        let lowEdge = Vector2(x: cos(-halfArc) * radius, y: sin(-halfArc) * radius)
        let highEdge = Vector2(x: cos(halfArc) * radius, y: sin(halfArc) * radius)

        func caught(_ target: Vector2, reversed: Bool) -> Bool {
            SweepGeometry.contains(
                targetCenter: target,
                targetRadius: balance.enemyRadius,
                sourceCenter: source,
                facing: facing,
                age: earlyAge,
                reversed: reversed,
                balance: balance
            )
        }

        #expect(caught(lowEdge, reversed: false))
        #expect(!caught(highEdge, reversed: false))
        #expect(caught(highEdge, reversed: true))
        #expect(!caught(lowEdge, reversed: true))
    }

    /// The simulation must replay identically, so direction cannot be random.
    @Test("Direction is fixed by the attack's identity")
    func directionIsDeterministic() {
        for sourceID in 0..<40 {
            for tick in stride(from: 0, to: 400, by: 37) {
                let first = SweepGeometry.isReversed(
                    sourceID: sourceID,
                    activationTick: tick
                )
                let second = SweepGeometry.isReversed(
                    sourceID: sourceID,
                    activationTick: tick
                )
                #expect(first == second)
            }
        }
    }

    @Test("Both directions actually occur, and neither dominates")
    func directionsAreMixed() {
        var reversedCount = 0
        var total = 0
        for sourceID in 1...60 {
            for tick in stride(from: 0, to: 600, by: 13) {
                total += 1
                if SweepGeometry.isReversed(sourceID: sourceID, activationTick: tick) {
                    reversedCount += 1
                }
            }
        }
        // A hash that clumps would leave long stretches swinging one way and
        // the variation would never be felt.
        let share = Double(reversedCount) / Double(total)
        #expect(share > 0.4)
        #expect(share < 0.6)
    }
}
