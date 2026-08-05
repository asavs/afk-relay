import CoreGraphics
import Testing
@testable import AFKRelay

@Suite("Arena impact sound policy")
@MainActor
struct ArenaImpactSoundPolicyTests {
    @Test("Ordinary friendly fire produces one graze cue")
    func ordinaryFriendlyFire() {
        let roles = ArenaImpactSoundPolicy.roles(for: [
            impact(id: "a"),
            impact(id: "b"),
        ])

        #expect(roles == [.friendlyFireImpact])
    }

    @Test("Discovery suppresses ordinary friendly-fire cues in its step")
    func discoveryWins() {
        let roles = ArenaImpactSoundPolicy.roles(for: [
            impact(id: "graze"),
            impact(id: "discovery", isEmphasized: true),
        ])

        #expect(roles == [.friendlyFireDiscovery])
    }

    @Test("Defeats collapse and suppress graze and discovery cues")
    func defeatWins() {
        let roles = ArenaImpactSoundPolicy.roles(for: [
            impact(id: "graze"),
            impact(id: "discovery", isEmphasized: true),
            impact(id: "defeat-a", isDefeat: true),
            impact(id: "defeat-b", isDefeat: true),
        ])

        #expect(roles == [.friendlyFireDefeat])
    }

    @Test("Player damage remains audible alongside a friendly-fire defeat")
    func separateChannelsRemainAudible() {
        let roles = ArenaImpactSoundPolicy.roles(for: [
            impact(id: "player", kind: .playerDamage),
            impact(id: "defeat", isDefeat: true),
        ])

        #expect(roles == [.playerDamageImpact, .friendlyFireDefeat])
    }

    private func impact(
        id: String,
        kind: ArenaRenderImpact.Kind = .friendlyFire,
        isDefeat: Bool = false,
        isEmphasized: Bool = false
    ) -> ArenaRenderImpact {
        ArenaRenderImpact(
            id: id,
            position: .zero,
            sourceEntityID: "E1",
            targetEntityID: "E2",
            kind: kind,
            isDefeat: isDefeat,
            isEmphasized: isEmphasized
        )
    }
}
