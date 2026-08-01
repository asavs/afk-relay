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
        balance: MVPBalance = .v2
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
        balance: MVPBalance = .v2
    ) -> ClosedRange<Double> {
        let center = atan2(facing.y, facing.x)
        let halfArc = radians(balance.sweepArcDegrees / 2)
        return (center - halfArc)...(center + halfArc)
    }

    static func activeBladeAngles(
        facing: Vector2,
        age: Double,
        balance: MVPBalance = .v2
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

        let telegraph = telegraphAngles(facing: facing, balance: balance)
        let bladeWidth = radians(balance.sweepBladeDegrees)
        let bladeHalf = bladeWidth / 2
        let center = telegraph.lowerBound
            + bladeHalf
            + (telegraph.upperBound - telegraph.lowerBound - bladeWidth)
                * min(max(progress, 0), 1)
        return (center - bladeHalf)...(center + bladeHalf)
    }

    static func contains(
        targetCenter: Vector2,
        targetRadius: Double,
        sourceCenter: Vector2,
        facing: Vector2,
        age: Double,
        balance: MVPBalance = .v2
    ) -> Bool {
        guard case .active = phase(at: age, balance: balance) else {
            return false
        }

        let blade = activeBladeAngles(
            facing: facing,
            age: age,
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
        balance: MVPBalance = .v2
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
            balance: balance
        )
        let endBlade = bladeAnglesAtInclusiveActiveAge(
            facing: facing,
            age: clippedEnd,
            balance: balance
        )
        return circleIntersectsSector(
            center: targetCenter,
            radius: targetRadius,
            origin: sourceCenter,
            reach: balance.sweepReach,
            angles: startBlade.lowerBound...endBlade.upperBound
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
        balance: MVPBalance
    ) -> ClosedRange<Double> {
        let activeStart = balance.sweepTelegraphDuration
        let progress = clampedRatio(
            age - activeStart,
            balance.sweepActiveDuration
        )
        let telegraph = telegraphAngles(facing: facing, balance: balance)
        let bladeWidth = radians(balance.sweepBladeDegrees)
        let halfWidth = bladeWidth / 2
        let center = telegraph.lowerBound
            + halfWidth
            + (telegraph.upperBound - telegraph.lowerBound - bladeWidth)
                * progress
        return (center - halfWidth)...(center + halfWidth)
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
