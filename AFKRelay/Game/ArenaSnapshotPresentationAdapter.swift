import CoreGraphics
import Foundation

/// Copies domain state into presentation-owned DTOs. No renderer resource can
/// flow back through this adapter into simulation.
@MainActor
enum ArenaSnapshotPresentationAdapter {
    static func makeSnapshot(
        from snapshot: ArenaSnapshot,
        events: [GameEvent] = [],
        previousPlayerPosition: Vector2? = nil,
        intendedPlayerPosition: Vector2? = nil,
        balance: MVPBalance = .v2,
        renderedFramesPerSecond: Int = 60
    ) -> ArenaRenderSnapshot {
        let allEntities = [snapshot.player] + snapshot.enemies
        let entities = allEntities.map { makeEntity($0, balance: balance) }
        let attacks = snapshot.attacks.compactMap { attack in
            makeAttack(
                attack,
                snapshot: snapshot,
                balance: balance
            )
        }
        // The tick that completes friendly-fire discovery marks its
        // friendly-fire impacts for amplified presentation (REQ-GAME-007).
        let emphasizeFriendlyFire = events.contains(.tutorialCompleted)
        let impacts = events.enumerated().compactMap { index, event in
            makeImpact(
                event,
                index: index,
                snapshot: snapshot,
                emphasizeFriendlyFire: emphasizeFriendlyFire
            )
        }
        let vectors = makeVectors(
            snapshot: snapshot,
            previousPlayerPosition: previousPlayerPosition,
            intendedPlayerPosition: intendedPlayerPosition
        )

        return ArenaRenderSnapshot(
            arenaSize: CGSize(
                width: balance.arenaSize.x,
                height: balance.arenaSize.y
            ),
            entities: entities,
            attacks: attacks,
            impacts: impacts,
            debugVectors: vectors,
            diagnostics: ArenaDiagnosticsMetrics(
                fixedStepHz: Int((1 / ArenaSimulation.fixedTimeStep).rounded()),
                renderedFramesPerSecond: renderedFramesPerSecond,
                livingEnemyCount: snapshot.enemies.count,
                activeAttackCount: snapshot.attacks.filter {
                    $0.isActive(balance: balance)
                }.count,
                simulationTick: UInt64(max(0, (snapshot.elapsed * 60).rounded(.down)))
            )
        )
    }

    private static func makeEntity(
        _ entity: ArenaEntity,
        balance: MVPBalance
    ) -> ArenaRenderEntity {
        let maximumHitPoints = entity.isPlayer
            ? balance.playerHitPoints
            : balance.enemyHitPoints
        // Renderer silhouettes point along +Y in texture space.
        let facingAngle = atan2(entity.facing.y, entity.facing.x) - .pi / 2

        return ArenaRenderEntity(
            id: entity.isPlayer ? "P0" : "E\(entity.id)",
            role: entity.isPlayer ? .playerBody : .enemyBody,
            position: point(entity.position),
            radius: entity.radius,
            facingAngle: facingAngle,
            hitPoints: entity.hitPoints,
            maximumHitPoints: maximumHitPoints
        )
    }

    private static func makeAttack(
        _ attack: ArenaAttack,
        snapshot: ArenaSnapshot,
        balance: MVPBalance
    ) -> ArenaRenderAttack? {
        guard let source = snapshot.enemies.first(where: { $0.id == attack.sourceID }) else {
            return nil
        }

        let telegraph = SweepGeometry.telegraphAngles(
            facing: attack.facing,
            balance: balance
        )
        let blade = SweepGeometry.activeBladeAngles(
            facing: attack.facing,
            age: attack.age,
            balance: balance
        )
        let phase: ArenaRenderAttack.Phase
        let phaseProgress: Double

        switch SweepGeometry.phase(at: attack.age, balance: balance) {
        case let .telegraph(progress):
            phase = .telegraph
            phaseProgress = progress
        case let .active(progress):
            phase = .active
            phaseProgress = progress
        case let .recovery(progress):
            phase = .recovery
            phaseProgress = progress
        case .finished:
            phase = .recovery
            phaseProgress = 1
        }

        let clampedProgress = min(max(phaseProgress, 0), 1)
        let activationTick = Int(
            max(0, ((snapshot.elapsed - attack.age) * 60).rounded())
        )

        return ArenaRenderAttack(
            id: "A\(attack.sourceID)-\(activationTick)",
            sourceEntityID: "E\(attack.sourceID)",
            origin: point(source.position),
            reach: balance.sweepReach,
            telegraphStartAngle: telegraph.lowerBound,
            telegraphEndAngle: telegraph.upperBound,
            activeStartAngle: blade.lowerBound,
            activeEndAngle: blade.upperBound,
            phase: phase,
            phaseProgress: clampedProgress
        )
    }

    private static func makeImpact(
        _ event: GameEvent,
        index: Int,
        snapshot: ArenaSnapshot,
        emphasizeFriendlyFire: Bool
    ) -> ArenaRenderImpact? {
        guard case let .damaged(target, source, _, position) = event else {
            return nil
        }

        let tick = Int(max(0, (snapshot.elapsed * 60).rounded(.down)))
        let kind: ArenaRenderImpact.Kind = target == snapshot.player.id
            ? .playerDamage
            : .friendlyFire
        return ArenaRenderImpact(
            id: "I\(tick)-\(source)-\(target)-\(index)",
            position: point(position),
            kind: kind,
            isEmphasized: emphasizeFriendlyFire && kind == .friendlyFire
        )
    }

    private static func makeVectors(
        snapshot: ArenaSnapshot,
        previousPlayerPosition: Vector2?,
        intendedPlayerPosition: Vector2?
    ) -> [ArenaRenderVector] {
        var vectors: [ArenaRenderVector] = []
        let tick = Int(max(0, (snapshot.elapsed * 60).rounded(.down)))

        if let previousPlayerPosition, let intendedPlayerPosition {
            vectors.append(
                ArenaRenderVector(
                    id: "intent-\(tick)",
                    start: point(previousPlayerPosition),
                    end: point(intendedPlayerPosition),
                    kind: .intendedPath
                )
            )
            vectors.append(
                ArenaRenderVector(
                    id: "resolved-\(tick)",
                    start: point(previousPlayerPosition),
                    end: point(snapshot.player.position),
                    kind: .resolvedPath
                )
            )

            for (index, normal) in snapshot.playerCollisionNormals.enumerated() {
                vectors.append(
                    ArenaRenderVector(
                        id: "collision-\(tick)-\(index)",
                        start: point(snapshot.player.position),
                        end: point(snapshot.player.position + normal * 80),
                        kind: .collisionNormal
                    )
                )
            }
        }

        for enemy in snapshot.enemies where enemy.velocity.length > 0 {
            vectors.append(
                ArenaRenderVector(
                    id: "pursuit-\(enemy.id)-\(tick)",
                    start: point(enemy.position),
                    end: point(enemy.position + enemy.velocity * 0.5),
                    kind: .pursuit
                )
            )
        }

        return vectors
    }

    private static func point(_ vector: Vector2) -> CGPoint {
        CGPoint(x: vector.x, y: vector.y)
    }
}
