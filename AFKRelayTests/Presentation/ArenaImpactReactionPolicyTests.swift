import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import AFKRelay

@Suite("Arena impact reactions")
@MainActor
struct ArenaImpactReactionPolicyTests {
    @Test(
        "Impact roles receive short frame-sized holds",
        arguments: [
            (ArenaRenderImpact.Kind.friendlyFire, false, 1.0 / 60.0),
            (ArenaRenderImpact.Kind.playerDamage, false, 2.0 / 60.0),
            (ArenaRenderImpact.Kind.friendlyFire, true, 3.0 / 60.0),
        ]
    )
    func reactionDurations(
        kind: ArenaRenderImpact.Kind,
        isEmphasized: Bool,
        expectedDuration: TimeInterval
    ) throws {
        let target = try #require(
            reactions(for: impact(kind, isEmphasized: isEmphasized))
                .first(where: { $0.role == .target })
        )

        #expect(target.holdDuration == expectedDuration)
        #expect(
            target.holdDuration
                <= ArenaImpactReactionPolicy.maximumHoldDuration
        )
    }

    @Test("Source and target react without freezing unrelated entities")
    func onlyInvolvedEntitiesReact() {
        let reactions = reactions(for: impact(.playerDamage))

        #expect(reactions.map(\.entityID) == ["E1", "E2"])
        #expect(reactions.map(\.role) == [.source, .target])
    }

    @Test("Clustered impacts collapse per entity to the strongest reaction")
    func clusteredImpactsCollapsePerEntity() throws {
        let ordinary = impact(
            .friendlyFire,
            id: "ordinary",
            sourceEntityID: "E1",
            targetEntityID: "E2"
        )
        let emphasized = impact(
            .friendlyFire,
            id: "emphasized",
            sourceEntityID: "E3",
            targetEntityID: "E2",
            isEmphasized: true
        )

        let target = try #require(
            ArenaImpactReactionPolicy.reactions(
                for: [ordinary, emphasized],
                accessibility: .standard
            ).first(where: { $0.entityID == "E2" })
        )

        #expect(target.role == .target)
        #expect(target.holdDuration == 3.0 / 60.0)
    }

    @Test("Reduce Motion removes animated reactions")
    func reduceMotionDisablesReactions() {
        var accessibility = ArenaAccessibilityOptions.standard
        accessibility.reduceMotion = true

        let reactions = ArenaImpactReactionPolicy.reactions(
            for: [impact(.playerDamage)],
            accessibility: accessibility
        )

        #expect(reactions.isEmpty)
    }

    @Test("Impact presentation never withholds fixed simulation steps")
    func sceneContinuesFixedStepsThroughImpact() {
        let scene = ArenaScene()
        var advancedSteps = 0
        scene.fixedStepHandler = { _ in
            advancedSteps += 1
            return ArenaRenderSnapshot(entities: [], attacks: [])
        }
        scene.publish(
            ArenaRenderSnapshot(
                entities: [],
                attacks: [],
                impacts: [impact(.playerDamage)]
            )
        )

        scene.update(0)
        scene.update(1.0 / 30.0)

        #expect(advancedSteps == 2)
    }

    @Test("Renderer reacts artwork while authoritative geometry stays current")
    func rendererSeparatesArtworkFromGeometry() throws {
        let renderer = ArenaRenderer()
        let scene = SKScene(size: CGSize(width: 390, height: 844))
        renderer.attach(to: scene)
        renderer.render(
            ArenaRenderSnapshot(
                entities: [
                    entity(id: "E1", x: 100),
                    entity(id: "E2", x: 200),
                    entity(id: "E3", x: 300),
                ],
                attacks: [],
                impacts: [impact(.friendlyFire)]
            )
        )

        let source = try #require(scene.childNode(withName: "//entity.E1"))
        let target = try #require(scene.childNode(withName: "//entity.E2"))
        let unrelated = try #require(scene.childNode(withName: "//entity.E3"))
        let sourceReaction = try #require(
            source.childNode(withName: "entity.reaction")
        )
        let targetReaction = try #require(
            target.childNode(withName: "entity.reaction")
        )
        let unrelatedReaction = try #require(
            unrelated.childNode(withName: "entity.reaction")
        )
        let targetHurtbox = try #require(
            target.childNode(withName: "entity.hurtbox")
        )

        #expect(source.position == CGPoint(x: 100, y: 100))
        #expect(target.position == CGPoint(x: 200, y: 100))
        #expect(sourceReaction.hasActions())
        #expect(targetReaction.hasActions())
        #expect(unrelatedReaction.hasActions() == false)
        #expect(targetHurtbox.xScale == 1)
        #expect(targetHurtbox.yScale == 1)
        #expect(targetReaction.xScale != 1)
        #expect(targetReaction.yScale != 1)
    }

    private func impact(
        _ kind: ArenaRenderImpact.Kind,
        id: String = "impact",
        sourceEntityID: String = "E1",
        targetEntityID: String = "E2",
        isEmphasized: Bool = false
    ) -> ArenaRenderImpact {
        ArenaRenderImpact(
            id: id,
            position: .zero,
            sourceEntityID: sourceEntityID,
            targetEntityID: targetEntityID,
            kind: kind,
            isEmphasized: isEmphasized
        )
    }

    private func reactions(
        for impact: ArenaRenderImpact
    ) -> [ArenaEntityImpactReaction] {
        ArenaImpactReactionPolicy.reactions(
            for: [impact],
            accessibility: .standard
        )
    }

    private func entity(id: String, x: CGFloat) -> ArenaRenderEntity {
        ArenaRenderEntity(
            id: id,
            role: .enemyBody,
            position: CGPoint(x: x, y: 100),
            radius: 30,
            facingAngle: 0,
            hitPoints: 2,
            maximumHitPoints: 2
        )
    }
}
