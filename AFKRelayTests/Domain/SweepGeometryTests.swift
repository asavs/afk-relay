import Foundation
import Testing
@testable import AFKRelay

@Suite("Rotating analytic sweep")
struct SweepGeometryTests {
    @Test("Phase boundaries are exact")
    func phaseBoundaries() {
        let balance = MVPBalance.v2

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
        let balance = MVPBalance.v2
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
        let balance = MVPBalance.v2
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
        let middleOfActive = MVPBalance.v2.sweepTelegraphDuration
            + MVPBalance.v2.sweepActiveDuration / 2

        #expect(
            !SweepGeometry.contains(
                targetCenter: target,
                targetRadius: 30,
                sourceCenter: .zero,
                facing: Vector2(x: 1, y: 0),
                age: middleOfActive,
                balance: .v2
            )
        )
    }

    @Test("The final advertised blade endpoint is included in swept evaluation")
    func finalSweptEndpoint() {
        let balance = MVPBalance.v2
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
        let balance = MVPBalance.v2
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
                ? MVPBalance.v2.playerRadius
                : MVPBalance.v2.enemyRadius,
            hitPoints: isPlayer
                ? MVPBalance.v2.playerHitPoints
                : MVPBalance.v2.enemyHitPoints,
            isPlayer: isPlayer
        )
    }
}
