import Foundation

/// A semantic physical-feedback moment. Gameplay emits framework-free events;
/// the SwiftUI shell decides how the current device represents each role.
nonisolated enum PresentationHapticRole: Equatable, Sendable {
    case buttonPress
    case playerDamage
    case friendlyFireImpact
    case friendlyFireDiscovery
    case gameOver
}

/// A changing trigger allows repeated occurrences of the same semantic role to
/// produce distinct feedback without feeding presentation state into gameplay.
nonisolated struct PresentationHapticEvent: Equatable, Sendable {
    let sequence: UInt64
    let role: PresentationHapticRole
}

nonisolated enum PresentationHapticPolicy {
    /// Chooses at most one feedback role for a fixed simulation step. Priority
    /// prevents simultaneous damage events from stacking several pulses.
    static func role(
        for events: [GameEvent],
        playerID: Int
    ) -> PresentationHapticRole? {
        if events.contains(.playerDefeated) {
            return .gameOver
        }

        if events.contains(where: { event in
            guard case let .damaged(target, _, _, _) = event else {
                return false
            }
            return target == playerID
        }) {
            return .playerDamage
        }

        if events.contains(.tutorialCompleted) {
            return .friendlyFireDiscovery
        }

        if events.contains(where: { event in
            guard case let .damaged(target, source, _, _) = event else {
                return false
            }
            return target != playerID && target != source
        }) {
            return .friendlyFireImpact
        }

        return nil
    }
}
