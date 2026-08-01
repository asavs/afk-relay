import Foundation
import Testing
@testable import AFKRelay

@Suite("Swept circle collision")
struct SweptCircleSolverTests {
    private let bounds = ArenaBounds(maxX: 500, maxY: 500)

    @Test("Head-on contact advances to impact without invented sideways motion")
    func headOnContact() {
        let result = SweptCircleSolver.solve(
            start: Vector2(x: 100, y: 100),
            displacement: Vector2(x: 100, y: 0),
            radius: 10,
            bounds: bounds,
            obstacles: [
                CircleObstacle(
                    id: 7,
                    center: Vector2(x: 150, y: 100),
                    radius: 10
                ),
            ]
        )

        #expect(abs(result.position.x - 130) < 0.000_001)
        #expect(abs(result.position.y - 100) < 0.000_001)
        #expect(abs(result.traveledDistance - 30) < 0.000_001)
        #expect(result.collisionNormals == [Vector2(x: -1, y: 0)])
    }

    @Test("Wall collision slides and charges only the traversed tangent")
    func wallSlide() {
        let result = SweptCircleSolver.solve(
            start: Vector2(x: 90, y: 50),
            displacement: Vector2(x: 30, y: 40),
            radius: 10,
            bounds: ArenaBounds(maxX: 100, maxY: 100),
            obstacles: []
        )

        #expect(abs(result.position.x - 90) < 0.000_001)
        #expect(abs(result.position.y - 90) < 0.000_001)
        #expect(abs(result.traveledDistance - 40) < 0.000_001)
        #expect(result.collisionNormals.first == Vector2(x: -1, y: 0))
    }

    @Test("A blocked path costs no movement")
    func blockedPathCostsNothing() {
        let result = SweptCircleSolver.solve(
            start: Vector2(x: 90, y: 50),
            displacement: Vector2(x: 10, y: 0),
            radius: 10,
            bounds: ArenaBounds(maxX: 100, maxY: 100),
            obstacles: []
        )
        var economy = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 1
        )

        let committed = MovementCostPolicy.commit(
            distance: result.traveledDistance,
            state: &economy
        )

        #expect(result.position == Vector2(x: 90, y: 50))
        #expect(result.traveledDistance == 0)
        #expect(committed == 0)
        #expect(economy.availableTokens == 1)
        #expect(economy.movementRemainder == 0)
    }

    @Test("Bounded multi-contact sliding cannot escape a corner")
    func cornerContact() {
        let result = SweptCircleSolver.solve(
            start: Vector2(x: 90, y: 90),
            displacement: Vector2(x: 30, y: 30),
            radius: 10,
            bounds: ArenaBounds(maxX: 100, maxY: 100),
            obstacles: []
        )

        #expect(result.position == Vector2(x: 90, y: 90))
        #expect(result.traveledDistance == 0)
        #expect(result.collisionNormals.count == 2)
    }

    @Test("Diagonal joystick intent is normalized before movement")
    func diagonalNormalization() {
        var arena = ArenaSimulation(tutorialCompleted: true)

        _ = arena.step(input: Vector2(x: 1, y: 1))

        #expect(
            abs(
                arena.lastPlayerTravelDistance
                    - MVPBalance.v2.playerSpeed * ArenaSimulation.fixedTimeStep
            ) < 0.000_001
        )
    }
}
