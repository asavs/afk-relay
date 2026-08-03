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
        balance: MVPBalance = .v4,
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
        let maximumHitPoints: Int = if entity.isPlayer {
            balance.playerHitPoints
        } else if entity.archetype == .marksman {
            balance.marksmanHitPoints
        } else {
            balance.enemyHitPoints
        }
        // Renderer silhouettes point along +Y in texture space.
        let facingAngle = atan2(entity.facing.y, entity.facing.x) - .pi / 2

        // Damage state travels as a semantic role so a catalog can render
        // wounded bodies however it likes (tint, limp, broken armor). The
        // archetype travels the same way: what a body can do to you is the
        // one thing its silhouette has to say.
        let role: PresentationRole = if entity.isPlayer {
            .playerBody
        } else if entity.archetype == .marksman {
            .enemyBodyRanged
        } else if entity.hitPoints < maximumHitPoints {
            .enemyBodyWounded
        } else {
            .enemyBody
        }
        return ArenaRenderEntity(
            id: entity.isPlayer ? "P0" : "E\(entity.id)",
            role: role,
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
        // Each attack's identity is its source and the tick it activated on,
        // which stays stable as it ages so the renderer keeps reusing one set
        // of nodes for it.
        let activationTick = Int(
            max(0, ((snapshot.elapsed - attack.age) * 60).rounded())
        )
        let id = "A\(attack.sourceID)-\(activationTick)"
        let sourceEntityID = "E\(attack.sourceID)"

        switch attack.kind {
        case .sweep:
            // A sweep is the source's own limb, so it is drawn from wherever
            // that body currently stands.
            guard let source = snapshot.enemies.first(where: {
                $0.id == attack.sourceID
            }) else {
                return nil
            }

            let telegraph = SweepGeometry.telegraphAngles(
                facing: attack.facing,
                balance: balance
            )
            let blade = SweepGeometry.activeBladeAngles(
                facing: attack.facing,
                age: attack.age,
                reversed: attack.isReversed,
                balance: balance
            )
            let (phase, progress) = sweepPhase(attack.age, balance: balance)

            return ArenaRenderAttack(
                id: id,
                sourceEntityID: sourceEntityID,
                origin: point(source.position),
                reach: balance.sweepReach,
                shape: .sweep(
                    ArenaRenderAttack.Sweep(
                        telegraphStartAngle: telegraph.lowerBound,
                        telegraphEndAngle: telegraph.upperBound,
                        activeStartAngle: blade.lowerBound,
                        activeEndAngle: blade.upperBound,
                        isReversed: attack.isReversed
                    )
                ),
                phase: phase,
                phaseProgress: progress
            )
        case .shot:
            // A shot is drawn from the muzzle it left, which is fixed — it
            // does not follow the shooter, and it outlives one.
            let nose = ShotGeometry.noseDistance(
                at: attack.age,
                stoppedAt: attack.stopDistance,
                balance: balance
            )
            let (phase, progress) = shotPhase(
                attack.age,
                stoppedAt: attack.stopDistance,
                balance: balance
            )

            return ArenaRenderAttack(
                id: id,
                sourceEntityID: sourceEntityID,
                origin: point(attack.origin),
                reach: balance.shotRange,
                shape: .shot(
                    ArenaRenderAttack.Shot(
                        axisAngle: atan2(attack.facing.y, attack.facing.x),
                        halfWidth: balance.shotRadius,
                        noseDistance: nose,
                        tailDistance: max(
                            0,
                            nose - balance.shotSpeed * boltTrailDuration
                        ),
                        isBlocked: attack.stopDistance != nil
                    )
                ),
                phase: phase,
                phaseProgress: progress
            )
        }
    }

    /// How long a stretch of lane the bolt itself occupies, expressed as the
    /// time it takes to cross it. Presentation only — hit evaluation is the
    /// nose's swept path, not this body.
    ///
    /// Long enough to read as a bolt rather than a dot. The lane is the
    /// warning, but the bolt is the thing that actually hits, and a player
    /// has to be able to see where it currently is.
    private static let boltTrailDuration = 0.11

    private static func sweepPhase(
        _ age: Double,
        balance: MVPBalance
    ) -> (ArenaRenderAttack.Phase, Double) {
        switch SweepGeometry.phase(at: age, balance: balance) {
        case let .telegraph(progress): (.telegraph, progress)
        case let .active(progress): (.active, progress)
        case let .recovery(progress): (.recovery, progress)
        case .finished: (.recovery, 1)
        }
    }

    private static func shotPhase(
        _ age: Double,
        stoppedAt: Double?,
        balance: MVPBalance
    ) -> (ArenaRenderAttack.Phase, Double) {
        switch ShotGeometry.phase(
            at: age,
            stoppedAt: stoppedAt,
            balance: balance
        ) {
        case let .telegraph(progress): (.telegraph, progress)
        case let .flight(progress): (.active, progress)
        case let .recovery(progress): (.recovery, progress)
        case .finished: (.recovery, 1)
        }
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
