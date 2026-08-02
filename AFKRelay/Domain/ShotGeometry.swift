import Foundation

nonisolated enum ShotAttackPhase: Equatable, Sendable {
    case telegraph(progress: Double)
    case flight(progress: Double)
    case recovery(progress: Double)
    case finished
}

/// The body a shot ran into, and how far along its axis that happened.
nonisolated struct ShotBlock: Equatable, Sendable {
    let targetID: Int
    let distance: Double
}

/// Analytic geometry for the linear projectile, shared by the simulation and
/// the presentation adapter exactly as `SweepGeometry` is.
///
/// A shot is a segment travelling along a fixed axis from a fixed muzzle. It
/// stops at the first body it meets rather than piercing (`ADR-0020`), so its
/// flight length is not known when it is fired — every query that depends on
/// where it ended takes the recorded stop distance.
nonisolated enum ShotGeometry {
    /// How far the nose has travelled from the muzzle.
    ///
    /// Clamped to the stop distance once one exists, so a blocked shot's
    /// geometry stays put for the rest of its life instead of drifting on
    /// through the body that stopped it.
    static func noseDistance(
        at age: Double,
        stoppedAt: Double? = nil,
        balance: MVPBalance = .v3
    ) -> Double {
        let flightAge = max(0, age) - balance.shotTelegraphDuration
        guard flightAge > 0 else { return 0 }
        let limit = min(stoppedAt ?? balance.shotRange, balance.shotRange)
        return min(max(0, flightAge * balance.shotSpeed), max(0, limit))
    }

    static func flightDuration(
        stoppedAt: Double? = nil,
        balance: MVPBalance = .v3
    ) -> Double {
        guard balance.shotSpeed > 0 else { return 0 }
        let travelled = min(max(stoppedAt ?? balance.shotRange, 0), balance.shotRange)
        return travelled / balance.shotSpeed
    }

    static func phase(
        at age: Double,
        stoppedAt: Double? = nil,
        balance: MVPBalance = .v3
    ) -> ShotAttackPhase {
        let nonnegativeAge = max(0, age)
        let telegraphEnd = balance.shotTelegraphDuration
        let flightEnd = telegraphEnd
            + flightDuration(stoppedAt: stoppedAt, balance: balance)
        let recoveryEnd = flightEnd + balance.shotRecoveryDuration

        if nonnegativeAge < telegraphEnd {
            return .telegraph(
                progress: clampedRatio(
                    nonnegativeAge,
                    balance.shotTelegraphDuration
                )
            )
        }

        if nonnegativeAge < flightEnd {
            return .flight(
                progress: clampedRatio(
                    nonnegativeAge - telegraphEnd,
                    flightEnd - telegraphEnd
                )
            )
        }

        if nonnegativeAge < recoveryEnd {
            return .recovery(
                progress: clampedRatio(
                    nonnegativeAge - flightEnd,
                    balance.shotRecoveryDuration
                )
            )
        }

        return .finished
    }

    /// The nearest body the shot's nose reaches while crossing
    /// `fromDistance...throughDistance` this tick, or `nil` if the lane is
    /// clear over that span.
    ///
    /// Nearest rather than every body: the shot stops at what it hits, so a
    /// tick that sweeps past two targets may only ever damage the first. The
    /// entry point is solved analytically from the target's circle rather than
    /// sampled, so a fast shot cannot tunnel through a body between ticks.
    static func firstBlock(
        origin: Vector2,
        axis: Vector2,
        fromDistance: Double,
        throughDistance: Double,
        targets: [ArenaEntity],
        sourceID: Int,
        balance: MVPBalance = .v3
    ) -> ShotBlock? {
        let epsilon = 0.000_000_001
        guard throughDistance >= fromDistance else { return nil }
        let direction = axis.normalized
        guard direction.length > 0 else { return nil }

        var nearest: ShotBlock?
        for target in targets
            where target.hitPoints > 0 && target.id != sourceID
        {
            let offset = target.position - origin
            let along = offset.dot(direction)
            let perpendicular = (offset - direction * along).length
            let combined = balance.shotRadius + target.radius
            guard perpendicular <= combined else { continue }

            // Where the nose first touches the target's circle, and where it
            // would leave it. A body that already straddles the nose — one
            // that walked into a shot already in flight — has an entry behind
            // this tick's span and is caught at the span's start.
            let half = (
                combined * combined - perpendicular * perpendicular
            ).squareRoot()
            let entry = along - half
            let exit = along + half
            guard exit >= fromDistance, entry <= throughDistance else {
                continue
            }

            let candidate = ShotBlock(
                targetID: target.id,
                distance: max(entry, fromDistance)
            )
            guard let current = nearest else {
                nearest = candidate
                continue
            }
            // Ties break on identifier so two bodies at the same distance
            // resolve the same way on every replay.
            if candidate.distance < current.distance - epsilon
                || (abs(candidate.distance - current.distance) <= epsilon
                    && candidate.targetID < current.targetID)
            {
                nearest = candidate
            }
        }

        return nearest
    }

    private static func clampedRatio(
        _ numerator: Double,
        _ denominator: Double
    ) -> Double {
        guard denominator > 0 else { return 1 }
        return min(max(numerator / denominator, 0), 1)
    }
}
