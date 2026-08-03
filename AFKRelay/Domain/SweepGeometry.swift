import Foundation

nonisolated enum SweepAttackPhase: Equatable, Sendable {
    case telegraph(progress: Double)
    case active(progress: Double)
    case recovery(progress: Double)
    case finished
}

/// Analytic geometry shared by simulation tests and the presentation adapter.
/// Angles are radians in the logical arena coordinate space.
nonisolated enum SweepGeometry {
    static func phase(
        at age: Double,
        balance: MVPBalance = .v4
    ) -> SweepAttackPhase {
        let nonnegativeAge = max(0, age)
        let telegraphEnd = balance.sweepTelegraphDuration
        let activeEnd = telegraphEnd + balance.sweepActiveDuration
        let recoveryEnd = activeEnd + balance.sweepRecoveryDuration

        if nonnegativeAge < telegraphEnd {
            return .telegraph(
                progress: clampedRatio(
                    nonnegativeAge,
                    balance.sweepTelegraphDuration
                )
            )
        }

        if nonnegativeAge < activeEnd {
            return .active(
                progress: clampedRatio(
                    nonnegativeAge - telegraphEnd,
                    balance.sweepActiveDuration
                )
            )
        }

        if nonnegativeAge < recoveryEnd {
            return .recovery(
                progress: clampedRatio(
                    nonnegativeAge - activeEnd,
                    balance.sweepRecoveryDuration
                )
            )
        }

        return .finished
    }

    static func telegraphAngles(
        facing: Vector2,
        balance: MVPBalance = .v4
    ) -> ClosedRange<Double> {
        let center = atan2(facing.y, facing.x)
        let halfArc = radians(balance.sweepArcDegrees / 2)
        return (center - halfArc)...(center + halfArc)
    }

    /// Which way a blade crosses its arc.
    ///
    /// Chosen per attack rather than fixed, so the direction has to be read
    /// each time instead of learned once. Derived from the attack's identity
    /// rather than drawn at random: the simulation is deterministic, and a
    /// run must replay identically from the same inputs.
    static func isReversed(sourceID: Int, activationTick: Int) -> Bool {
        // A cheap integer mix. Neighbouring ids and adjacent ticks have to
        // land on different bits, or a row of enemies triggering together
        // would all swing the same way and the variation would be invisible.
        var hash = UInt64(bitPattern: Int64(sourceID &* 0x9E37_79B9))
        hash ^= UInt64(bitPattern: Int64(activationTick &* 0x85EB_CA6B))
        hash = (hash ^ (hash >> 33)) &* 0xFF51_AFD7_ED55_8CCD
        hash = (hash ^ (hash >> 33)) &* 0xC4CE_B9FE_1A85_EC53
        return (hash >> 33) & 1 == 1
    }

    static func activeBladeAngles(
        facing: Vector2,
        age: Double,
        reversed: Bool = false,
        balance: MVPBalance = .v4
    ) -> ClosedRange<Double> {
        let progress: Double
        switch phase(at: age, balance: balance) {
        case let .active(value):
            progress = value
        case .recovery:
            progress = 1
        case .telegraph:
            progress = 0
        case .finished:
            progress = 1
        }

        return bladeAngles(
            facing: facing,
            progress: min(max(progress, 0), 1),
            reversed: reversed,
            balance: balance
        )
    }

    private static func bladeAngles(
        facing: Vector2,
        progress: Double,
        reversed: Bool,
        balance: MVPBalance
    ) -> ClosedRange<Double> {
        let telegraph = telegraphAngles(facing: facing, balance: balance)
        let bladeWidth = radians(balance.sweepBladeDegrees)
        let bladeHalf = bladeWidth / 2
        let travel = telegraph.upperBound - telegraph.lowerBound - bladeWidth
        // A reversed blade starts at the far edge and runs back, so the same
        // progress measures the same distance travelled either way.
        let travelled = reversed ? (1 - progress) : progress
        let center = telegraph.lowerBound + bladeHalf + travel * travelled
        return (center - bladeHalf)...(center + bladeHalf)
    }

    static func contains(
        targetCenter: Vector2,
        targetRadius: Double,
        sourceCenter: Vector2,
        facing: Vector2,
        age: Double,
        reversed: Bool = false,
        balance: MVPBalance = .v4
    ) -> Bool {
        guard case .active = phase(at: age, balance: balance) else {
            return false
        }

        let blade = activeBladeAngles(
            facing: facing,
            age: age,
            reversed: reversed,
            balance: balance
        )
        return circleIntersectsSector(
            center: targetCenter,
            radius: targetRadius,
            origin: sourceCenter,
            reach: balance.sweepReach,
            angles: blade
        )
    }

    /// Evaluates the full blade geometry traversed during one fixed step,
    /// including the exact final active endpoint before recovery begins.
    static func containsSwept(
        targetCenter: Vector2,
        targetRadius: Double,
        sourceCenter: Vector2,
        facing: Vector2,
        fromAge: Double,
        throughAge: Double,
        reversed: Bool = false,
        balance: MVPBalance = .v4
    ) -> Bool {
        let activeStart = balance.sweepTelegraphDuration
        let activeEnd = activeStart + balance.sweepActiveDuration
        let clippedStart = min(max(fromAge, activeStart), activeEnd)
        let clippedEnd = min(max(throughAge, activeStart), activeEnd)

        guard
            throughAge >= activeStart,
            fromAge <= activeEnd,
            clippedEnd >= clippedStart
        else {
            return false
        }

        let startBlade = bladeAnglesAtInclusiveActiveAge(
            facing: facing,
            age: clippedStart,
            reversed: reversed,
            balance: balance
        )
        let endBlade = bladeAnglesAtInclusiveActiveAge(
            facing: facing,
            age: clippedEnd,
            reversed: reversed,
            balance: balance
        )
        // A reversed blade ends at a lower angle than it started, so the
        // ground it crossed is the span between them either way round.
        let sweptLower = min(startBlade.lowerBound, endBlade.lowerBound)
        let sweptUpper = max(startBlade.upperBound, endBlade.upperBound)
        return circleIntersectsSector(
            center: targetCenter,
            radius: targetRadius,
            origin: sourceCenter,
            reach: balance.sweepReach,
            angles: sweptLower...sweptUpper
        )
    }

    static func shortestAngle(_ angle: Double) -> Double {
        var result = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if result > .pi {
            result -= 2 * .pi
        } else if result < -.pi {
            result += 2 * .pi
        }
        return result
    }

    private static func clampedRatio(_ numerator: Double, _ denominator: Double) -> Double {
        guard denominator > 0 else { return 1 }
        return min(max(numerator / denominator, 0), 1)
    }

    private static func bladeAnglesAtInclusiveActiveAge(
        facing: Vector2,
        age: Double,
        reversed: Bool,
        balance: MVPBalance
    ) -> ClosedRange<Double> {
        let activeStart = balance.sweepTelegraphDuration
        let progress = clampedRatio(
            age - activeStart,
            balance.sweepActiveDuration
        )
        return bladeAngles(
            facing: facing,
            progress: progress,
            reversed: reversed,
            balance: balance
        )
    }

    private static func circleIntersectsSector(
        center: Vector2,
        radius: Double,
        origin: Vector2,
        reach: Double,
        angles: ClosedRange<Double>
    ) -> Bool {
        let safeRadius = max(0, radius)
        let safeReach = max(0, reach)
        let offset = center - origin
        let distance = offset.length
        guard distance <= safeReach + safeRadius else { return false }
        guard distance > 0.000_001 else { return true }

        let sectorCenter = (angles.lowerBound + angles.upperBound) / 2
        let halfArc = (angles.upperBound - angles.lowerBound) / 2
        let targetOffsetAngle = shortestAngle(
            atan2(offset.y, offset.x) - sectorCenter
        )

        if distance <= safeReach,
           abs(targetOffsetAngle) <= halfArc
        {
            return true
        }

        let lowerEndpoint = origin + Vector2(
            x: cos(angles.lowerBound),
            y: sin(angles.lowerBound)
        ) * safeReach
        let upperEndpoint = origin + Vector2(
            x: cos(angles.upperBound),
            y: sin(angles.upperBound)
        ) * safeReach

        if distanceToSegment(center, origin, lowerEndpoint) <= safeRadius
            || distanceToSegment(center, origin, upperEndpoint) <= safeRadius
        {
            return true
        }

        return abs(distance - safeReach) <= safeRadius
            && abs(targetOffsetAngle) <= halfArc
    }

    private static func distanceToSegment(
        _ point: Vector2,
        _ start: Vector2,
        _ end: Vector2
    ) -> Double {
        let segment = end - start
        guard segment.lengthSquared > 0 else {
            return point.distance(to: start)
        }
        let projection = min(
            max((point - start).dot(segment) / segment.lengthSquared, 0),
            1
        )
        return point.distance(to: start + segment * projection)
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }
}
