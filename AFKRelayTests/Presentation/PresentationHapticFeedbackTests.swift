import Testing
@testable import AFKRelay

@Suite("Presentation haptic feedback")
struct PresentationHapticFeedbackTests {
    private let playerID = 0

    @Test("Defeat takes priority over its lethal damage event")
    func defeatPriority() {
        let events = [
            damage(target: playerID, source: 1),
            .playerDefeated,
        ]

        #expect(role(for: events) == .gameOver)
    }

    @Test("Player damage takes priority over simultaneous friendly fire")
    func playerDamagePriority() {
        let events = [
            damage(target: 2, source: 1),
            damage(target: playerID, source: 1),
        ]

        #expect(role(for: events) == .playerDamage)
    }

    @Test("Tutorial completion emphasizes the discovery impact")
    func discoveryPriority() {
        let events = [
            damage(target: 2, source: 1),
            .tutorialCompleted,
        ]

        #expect(role(for: events) == .friendlyFireDiscovery)
    }

    @Test("Later enemy damage produces the standard impact")
    func friendlyFireImpact() {
        #expect(
            role(for: [damage(target: 2, source: 1)])
                == .friendlyFireImpact
        )
    }

    @Test("Non-impact events produce no haptic role")
    func unrelatedEvents() {
        #expect(role(for: [.spawned(1)]) == nil)
    }

    private func role(for events: [GameEvent]) -> PresentationHapticRole? {
        PresentationHapticPolicy.role(for: events, playerID: playerID)
    }

    private func damage(target: Int, source: Int) -> GameEvent {
        .damaged(
            target: target,
            source: source,
            amount: 1,
            position: .zero
        )
    }
}
