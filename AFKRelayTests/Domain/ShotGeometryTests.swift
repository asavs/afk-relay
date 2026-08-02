import Foundation
import Testing
@testable import AFKRelay

@Suite("Linear shot geometry")
struct ShotGeometryTests {
    @Test("Phase boundaries are exact")
    func phaseBoundaries() {
        let balance = MVPBalance.v3
        let flightEnd = balance.shotTelegraphDuration
            + balance.shotRange / balance.shotSpeed

        #expect(ShotGeometry.phase(at: 0) == .telegraph(progress: 0))
        #expect(
            ShotGeometry.phase(at: balance.shotTelegraphDuration)
                == .flight(progress: 0)
        )
        #expect(ShotGeometry.phase(at: flightEnd) == .recovery(progress: 0))
        #expect(
            ShotGeometry.phase(at: flightEnd + balance.shotRecoveryDuration)
                == .finished
        )
    }

    @Test("A blocked shot spends the rest of its life in recovery")
    func blockedFlightEndsEarly() {
        let balance = MVPBalance.v3
        let stop = 200.0
        let blockedFlightEnd = balance.shotTelegraphDuration
            + stop / balance.shotSpeed

        // The same age is still flight for a shot with a clear lane and
        // already recovery for one that hit something at 200.
        if case .flight = ShotGeometry.phase(at: blockedFlightEnd) {} else {
            Issue.record("A clear shot should still be in flight at \(blockedFlightEnd)")
        }
        #expect(
            ShotGeometry.phase(at: blockedFlightEnd, stoppedAt: stop)
                == .recovery(progress: 0)
        )
        #expect(
            ShotGeometry.phase(
                at: blockedFlightEnd + balance.shotRecoveryDuration,
                stoppedAt: stop
            ) == .finished
        )
    }

    @Test("The nose stops where the shot stopped, and never passes its range")
    func noseDistanceClamps() {
        let balance = MVPBalance.v3
        let longAfterFiring = balance.shotTelegraphDuration + 10

        #expect(ShotGeometry.noseDistance(at: 0) == 0)
        #expect(ShotGeometry.noseDistance(at: balance.shotTelegraphDuration) == 0)
        #expect(
            abs(
                ShotGeometry.noseDistance(
                    at: balance.shotTelegraphDuration + 0.5
                ) - balance.shotSpeed * 0.5
            ) < 0.000_001
        )
        #expect(
            ShotGeometry.noseDistance(at: longAfterFiring) == balance.shotRange
        )
        #expect(
            ShotGeometry.noseDistance(at: longAfterFiring, stoppedAt: 120) == 120
        )
    }

    @Test("A shot stops at the nearest body rather than piercing the line")
    func nearestBodyBlocks() {
        let near = entity(id: 4, position: Vector2(x: 200, y: 0))
        let far = entity(id: 5, position: Vector2(x: 400, y: 0))

        let block = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 800,
            targets: [far, near],
            sourceID: 1
        )

        #expect(block?.targetID == 4)
        // Contact is the near edge of the body, not its centre.
        #expect(
            abs((block?.distance ?? 0) - (200 - MVPBalance.v3.shotRadius - near.radius))
                < 0.000_001
        )
    }

    @Test("A shot passes over its own source and over the dead")
    func sourceAndDeadAreNotBlockers() {
        let source = entity(id: 1, position: Vector2(x: 100, y: 0))
        let corpse = entity(id: 2, position: Vector2(x: 200, y: 0), hitPoints: 0)
        let living = entity(id: 3, position: Vector2(x: 300, y: 0))

        let block = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 800,
            targets: [source, corpse, living],
            sourceID: 1
        )

        #expect(block?.targetID == 3)
    }

    @Test("The lane is exactly the shot radius plus the target's own")
    func laneWidthIsAnalytic() {
        let balance = MVPBalance.v3
        let radius = 30.0
        let grazing = balance.shotRadius + radius

        let hit = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 800,
            targets: [
                entity(id: 2, position: Vector2(x: 300, y: grazing - 0.001), radius: radius),
            ],
            sourceID: 1
        )
        let miss = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 800,
            targets: [
                entity(id: 2, position: Vector2(x: 300, y: grazing + 0.001), radius: radius),
            ],
            sourceID: 1
        )

        #expect(hit?.targetID == 2)
        #expect(miss == nil)
    }

    @Test("A fast shot cannot tunnel through a body between two ticks")
    func noTunnelling() {
        let target = entity(id: 2, position: Vector2(x: 400, y: 0))

        // One absurd step that starts before the body and ends past it.
        let block = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 100_000,
            targets: [target],
            sourceID: 1
        )

        #expect(block?.targetID == 2)
        #expect(
            abs((block?.distance ?? 0) - (400 - MVPBalance.v3.shotRadius - target.radius))
                < 0.000_001
        )
    }

    @Test("A body that walks into a shot already in flight is caught")
    func bodyWalksIntoFlight() {
        // The body straddles the nose: it entered the lane behind where this
        // tick begins, so the contact is registered at the start of the span.
        let target = entity(id: 2, position: Vector2(x: 500, y: 0))

        let block = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 500,
            throughDistance: 510,
            targets: [target],
            sourceID: 1
        )

        #expect(block?.targetID == 2)
        #expect(block?.distance == 500)
    }

    @Test("Bodies at the same distance resolve on identifier, not on order")
    func tiesAreDeterministic() {
        let combined = MVPBalance.v3.shotRadius + 34
        let upper = entity(id: 7, position: Vector2(x: 300, y: combined / 2))
        let lower = entity(id: 3, position: Vector2(x: 300, y: -combined / 2))

        let forward = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 800,
            targets: [upper, lower],
            sourceID: 1
        )
        let reversed = ShotGeometry.firstBlock(
            origin: .zero,
            axis: Vector2(x: 1, y: 0),
            fromDistance: 0,
            throughDistance: 800,
            targets: [lower, upper],
            sourceID: 1
        )

        #expect(forward?.targetID == 3)
        #expect(forward == reversed)
    }

    @Test("A clear lane blocks nothing")
    func clearLane() {
        #expect(
            ShotGeometry.firstBlock(
                origin: .zero,
                axis: Vector2(x: 1, y: 0),
                fromDistance: 0,
                throughDistance: 800,
                targets: [entity(id: 2, position: Vector2(x: 0, y: 400))],
                sourceID: 1
            ) == nil
        )
    }

    private func entity(
        id: Int,
        position: Vector2,
        radius: Double = 34,
        hitPoints: Int = 2
    ) -> ArenaEntity {
        ArenaEntity(
            id: id,
            position: position,
            velocity: .zero,
            facing: Vector2(x: 1, y: 0),
            radius: radius,
            hitPoints: hitPoints,
            isPlayer: false
        )
    }
}
