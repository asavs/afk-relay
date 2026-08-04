import Foundation

nonisolated struct ArenaEntityImpactReaction: Equatable, Sendable {
    enum Role: Equatable, Sendable {
        case source
        case target
    }

    let entityID: String
    let role: Role
    let holdDuration: TimeInterval
}

/// Selects short, presentation-only reactions for the artwork involved in an
/// impact. Authoritative simulation and diagnostic geometry continue normally.
nonisolated enum ArenaImpactReactionPolicy {
    static let maximumHoldDuration: TimeInterval = 3.0 / 60.0

    static func reactions(
        for impacts: [ArenaRenderImpact],
        accessibility: ArenaAccessibilityOptions
    ) -> [ArenaEntityImpactReaction] {
        guard accessibility.reduceMotion == false else { return [] }

        var reactionsByEntityID: [String: ArenaEntityImpactReaction] = [:]
        for impact in impacts {
            let duration = holdDuration(for: impact)
            merge(
                ArenaEntityImpactReaction(
                    entityID: impact.sourceEntityID,
                    role: .source,
                    holdDuration: duration
                ),
                into: &reactionsByEntityID
            )
            merge(
                ArenaEntityImpactReaction(
                    entityID: impact.targetEntityID,
                    role: .target,
                    holdDuration: duration
                ),
                into: &reactionsByEntityID
            )
        }

        return reactionsByEntityID.values.sorted {
            if $0.entityID == $1.entityID {
                return rolePriority($0.role) > rolePriority($1.role)
            }
            return $0.entityID < $1.entityID
        }
    }

    private static func holdDuration(
        for impact: ArenaRenderImpact
    ) -> TimeInterval {
        let duration: TimeInterval
        if impact.isEmphasized {
            duration = 3.0 / 60.0
        } else {
            duration = switch impact.kind {
            case .playerDamage: 2.0 / 60.0
            case .friendlyFire: 1.0 / 60.0
            }
        }
        return min(max(duration, 0), maximumHoldDuration)
    }

    private static func merge(
        _ candidate: ArenaEntityImpactReaction,
        into reactions: inout [String: ArenaEntityImpactReaction]
    ) {
        guard let current = reactions[candidate.entityID] else {
            reactions[candidate.entityID] = candidate
            return
        }

        if candidate.holdDuration > current.holdDuration
            || (candidate.holdDuration == current.holdDuration
                && rolePriority(candidate.role) > rolePriority(current.role))
        {
            reactions[candidate.entityID] = candidate
        }
    }

    private static func rolePriority(
        _ role: ArenaEntityImpactReaction.Role
    ) -> Int {
        switch role {
        case .source: 0
        case .target: 1
        }
    }
}
