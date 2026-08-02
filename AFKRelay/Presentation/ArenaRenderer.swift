import SpriteKit

/// Incremental SpriteKit renderer for immutable presentation snapshots.
///
/// `ArenaRenderer` never advances time or mutates gameplay state. Its only
/// authority is the node tree it owns.
@MainActor
final class ArenaRenderer {
    let rootNode = SKNode()

    private let catalog: any ArenaPresentationCatalog
    private let telegraphTextures = TelegraphTextureCache()
    private let gridNode = SKShapeNode()
    private let boundaryNode = SKShapeNode()
    private let attackLayer = SKNode()
    private let entityLayer = SKNode()
    private let impactLayer = SKNode()
    private let diagnosticsLayer = SKNode()
    private var entityNodes: [String: EntityNodes] = [:]
    private var attackNodes: [String: AttackNodes] = [:]
    private var renderedImpactIDs: Set<String> = []
    private var lastPlayerPosition: CGPoint?
    private var cachedBoundaryOuter: CGRect?
    private var cachedGridBounds: CGRect?
    private var viewportSize: CGSize = .zero
    private var arenaSize = CGSize(width: 1000, height: 1500)

    init(catalog: any ArenaPresentationCatalog = DiagnosticCatalog()) {
        self.catalog = catalog
        configureNodeTree()
    }

    var backgroundColor: SKColor {
        catalog.style(for: .arenaBackground, accessibility: .standard).fillColor
    }

    func attach(to scene: SKScene) {
        guard rootNode.parent !== scene else { return }
        rootNode.removeFromParent()
        scene.addChild(rootNode)
        scene.backgroundColor = backgroundColor
        setViewportSize(scene.size)
    }

    func setViewportSize(_ size: CGSize) {
        viewportSize = size
        layoutWorld()
    }

    func render(
        _ snapshot: ArenaRenderSnapshot,
        diagnostics options: DiagnosticsOptions = .disabled,
        accessibility: ArenaAccessibilityOptions = .standard
    ) {
        if snapshot.arenaSize != arenaSize {
            arenaSize = snapshot.arenaSize
            layoutWorld()
        }

        rootNode.scene?.backgroundColor = catalog
            .style(for: .arenaBackground, accessibility: accessibility)
            .fillColor
        updateFloorGrid(accessibility: accessibility)
        updateBoundary(accessibility: accessibility)
        updateEntities(snapshot.entities, diagnostics: options, accessibility: accessibility)
        updateAttacks(snapshot.attacks, diagnostics: options, accessibility: accessibility)
        updateImpacts(snapshot.impacts, accessibility: accessibility)
        updateDebugVectors(snapshot.debugVectors, diagnostics: options, accessibility: accessibility)
    }

    private func configureNodeTree() {
        rootNode.name = "presentation.root"
        rootNode.addChild(gridNode)
        rootNode.addChild(boundaryNode)
        rootNode.addChild(attackLayer)
        rootNode.addChild(entityLayer)
        rootNode.addChild(impactLayer)
        rootNode.addChild(diagnosticsLayer)

        gridNode.name = "arena.floor-grid"
        boundaryNode.name = "arena.boundary"
        attackLayer.name = "presentation.attacks"
        entityLayer.name = "presentation.entities"
        impactLayer.name = "presentation.impacts"
        diagnosticsLayer.name = "presentation.diagnostics"
    }

    private func layoutWorld() {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              arenaSize.width > 0,
              arenaSize.height > 0
        else {
            return
        }

        let scale = min(
            viewportSize.width / arenaSize.width,
            viewportSize.height / arenaSize.height
        )
        rootNode.setScale(scale)
        rootNode.position = CGPoint(
            x: (viewportSize.width - arenaSize.width * scale) / 2,
            y: (viewportSize.height - arenaSize.height * scale) / 2
        )
    }

    /// The world has no frame. The floor grid runs edge to edge across the
    /// whole viewport, and everything beyond the playable bounds sits in
    /// shadow: walls read as where the light ends, not as a drawn box.
    private func updateBoundary(accessibility: ArenaAccessibilityOptions) {
        let overhang = worldOverhang()
        let outer = CGRect(origin: .zero, size: arenaSize)
            .insetBy(dx: -overhang.dx, dy: -overhang.dy)
        if cachedBoundaryOuter != outer {
            // Four shade bands around the playfield; SKShapeNode has no
            // fill rule, so the ring is built from rectangles.
            let arena = CGRect(origin: .zero, size: arenaSize)
            let path = CGMutablePath()
            path.addRect(CGRect(
                x: outer.minX, y: arena.maxY,
                width: outer.width, height: outer.maxY - arena.maxY
            ))
            path.addRect(CGRect(
                x: outer.minX, y: outer.minY,
                width: outer.width, height: arena.minY - outer.minY
            ))
            path.addRect(CGRect(
                x: outer.minX, y: arena.minY,
                width: arena.minX - outer.minX, height: arena.height
            ))
            path.addRect(CGRect(
                x: arena.maxX, y: arena.minY,
                width: outer.maxX - arena.maxX, height: arena.height
            ))
            boundaryNode.path = path
            cachedBoundaryOuter = outer
        }

        boundaryNode.fillColor = SKColor.black.withAlphaComponent(
            accessibility.increaseContrast ? 0.72 : 0.5
        )
        boundaryNode.strokeColor = .clear
        boundaryNode.lineWidth = 0
        boundaryNode.zPosition = -30
    }

    /// The floor grid anchors distance judgment. Its look comes entirely
    /// from the catalog's background role.
    private func updateFloorGrid(accessibility: ArenaAccessibilityOptions) {
        let style = catalog.style(for: .arenaBackground, accessibility: accessibility)
        let overhang = worldOverhang()
        let bounds = CGRect(origin: .zero, size: arenaSize)
            .insetBy(dx: -overhang.dx, dy: -overhang.dy)
        if cachedGridBounds != bounds {
            let spacing = 100.0
            let path = CGMutablePath()
            var x = (bounds.minX / spacing).rounded(.down) * spacing
            while x <= bounds.maxX {
                path.move(to: CGPoint(x: x, y: bounds.minY))
                path.addLine(to: CGPoint(x: x, y: bounds.maxY))
                x += spacing
            }
            var y = (bounds.minY / spacing).rounded(.down) * spacing
            while y <= bounds.maxY {
                path.move(to: CGPoint(x: bounds.minX, y: y))
                path.addLine(to: CGPoint(x: bounds.maxX, y: y))
                y += spacing
            }

            // A center cross anchors orientation: the spawn point reads as
            // a place, not just more floor.
            let center = CGPoint(x: arenaSize.width / 2, y: arenaSize.height / 2)
            let arm = 18.0
            path.move(to: CGPoint(x: center.x - arm, y: center.y))
            path.addLine(to: CGPoint(x: center.x + arm, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - arm))
            path.addLine(to: CGPoint(x: center.x, y: center.y + arm))
            gridNode.path = path
            cachedGridBounds = bounds
        }
        gridNode.fillColor = .clear
        gridNode.strokeColor = style.strokeColor
        gridNode.lineWidth = style.lineWidth
        gridNode.zPosition = -40
    }

    /// World-space distance from the arena edges to the viewport edges,
    /// with margin so the shaded out-of-bounds always reaches the screen.
    private func worldOverhang() -> (dx: Double, dy: Double) {
        let scale = min(
            viewportSize.width / max(arenaSize.width, 1),
            viewportSize.height / max(arenaSize.height, 1)
        )
        guard scale > 0 else { return (200, 200) }
        let dx = (viewportSize.width / scale - arenaSize.width) / 2 + 200
        let dy = (viewportSize.height / scale - arenaSize.height) / 2 + 200
        return (dx, dy)
    }

    private func updateEntities(
        _ entities: [ArenaRenderEntity],
        diagnostics: DiagnosticsOptions,
        accessibility: ArenaAccessibilityOptions
    ) {
        let currentIDs = Set(entities.map(\.id))
        for id in entityNodes.keys where !currentIDs.contains(id) {
            entityNodes.removeValue(forKey: id)?.container.removeFromParent()
        }

        for entity in entities {
            let nodes = entityNodes[entity.id] ?? makeEntityNodes(for: entity)
            entityNodes[entity.id] = nodes
            if entity.role == .playerBody {
                emitMovementTrail(for: entity, accessibility: accessibility)
            }
            update(nodes, with: entity, diagnostics: diagnostics, accessibility: accessibility)
        }
    }

    private func makeEntityNodes(for entity: ArenaRenderEntity) -> EntityNodes {
        let container = SKNode()
        let body = SKSpriteNode()
        let hurtbox = SKShapeNode()
        let facingMarker = SKShapeNode()
        let identifier = makeLabel()

        container.name = "entity.\(entity.id)"
        body.name = "entity.body"
        hurtbox.name = "entity.hurtbox"
        facingMarker.name = "entity.facing"
        identifier.name = "entity.identifier"

        container.addChild(hurtbox)
        container.addChild(body)
        container.addChild(facingMarker)
        container.addChild(identifier)
        entityLayer.addChild(container)

        return EntityNodes(
            container: container,
            body: body,
            hurtbox: hurtbox,
            facingMarker: facingMarker,
            identifier: identifier,
            previousHitPoints: entity.hitPoints
        )
    }

    private func update(
        _ nodes: EntityNodes,
        with entity: ArenaRenderEntity,
        diagnostics: DiagnosticsOptions,
        accessibility: ArenaAccessibilityOptions
    ) {
        let bodyStyle = catalog.style(for: entity.role, accessibility: accessibility)
        let hurtboxRole: PresentationRole = entity.role == .playerBody
            ? .playerHurtbox
            : .enemyHurtbox
        let hurtboxStyle = catalog.style(for: hurtboxRole, accessibility: accessibility)
        let diameter = entity.radius * 2

        nodes.container.position = entity.position
        nodes.container.zRotation = 0
        nodes.body.texture = catalog.entityTexture(for: entity.role, accessibility: accessibility)
        nodes.body.size = CGSize(width: diameter, height: diameter)
        nodes.body.zRotation = entity.facingAngle
        nodes.body.zPosition = 2

        nodes.hurtbox.path = CGPath(
            ellipseIn: CGRect(
                x: -entity.radius,
                y: -entity.radius,
                width: diameter,
                height: diameter
            ),
            transform: nil
        )
        apply(hurtboxStyle, to: nodes.hurtbox)

        let markerLength = max(12, entity.radius * 0.65)
        let markerPath = CGMutablePath()
        markerPath.move(to: CGPoint(x: 0, y: entity.radius * 0.35))
        markerPath.addLine(to: CGPoint(x: 0, y: entity.radius * 0.35 + markerLength))
        nodes.facingMarker.path = markerPath
        nodes.facingMarker.strokeColor = bodyStyle.strokeColor
        nodes.facingMarker.lineWidth = max(3, bodyStyle.lineWidth * 0.75)
        nodes.facingMarker.zRotation = entity.facingAngle
        nodes.facingMarker.zPosition = 3

        nodes.identifier.text = entity.id
        nodes.identifier.position = CGPoint(x: 0, y: -(entity.radius + 28))
        nodes.identifier.isHidden = !(diagnostics.isEnabled && diagnostics.showsEntityIdentifiers)

        if entity.hitPoints < nodes.previousHitPoints {
            showDamageFeedback(on: nodes.body, reduceMotion: accessibility.reduceMotion)
        }
        nodes.previousHitPoints = entity.hitPoints
    }

    /// Spent movement leaves a fading wake behind the player, giving the
    /// core verb a visible body. Pure presentation; skipped entirely for
    /// Reduce Motion users.
    private func emitMovementTrail(
        for entity: ArenaRenderEntity,
        accessibility: ArenaAccessibilityOptions
    ) {
        defer { lastPlayerPosition = entity.position }
        guard !accessibility.reduceMotion,
              let previous = lastPlayerPosition
        else {
            return
        }

        let dx = entity.position.x - previous.x
        let dy = entity.position.y - previous.y
        guard dx * dx + dy * dy > 4 else { return }

        let style = catalog.style(for: .playerBody, accessibility: accessibility)
        let wake = SKShapeNode(circleOfRadius: entity.radius * 0.4)
        wake.position = previous
        wake.fillColor = style.fillColor.withAlphaComponent(0.28)
        wake.strokeColor = .clear
        wake.zPosition = 1
        entityLayer.addChild(wake)
        wake.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.4),
                .scale(to: 0.4, duration: 0.4),
            ]),
            .removeFromParent(),
        ]))
    }

    private func showDamageFeedback(on node: SKNode, reduceMotion: Bool) {
        node.removeAction(forKey: "damage-feedback")
        let fade = SKAction.sequence([
            .fadeAlpha(to: 0.35, duration: 0.06),
            .fadeAlpha(to: 1, duration: 0.12),
        ])

        if reduceMotion {
            node.run(fade, withKey: "damage-feedback")
        } else {
            let scale = SKAction.sequence([
                .scale(to: 1.18, duration: 0.06),
                .scale(to: 1, duration: 0.12),
            ])
            node.run(.group([fade, scale]), withKey: "damage-feedback")
        }
    }

    private func updateAttacks(
        _ attacks: [ArenaRenderAttack],
        diagnostics: DiagnosticsOptions,
        accessibility: ArenaAccessibilityOptions
    ) {
        let currentIDs = Set(attacks.map(\.id))
        for id in attackNodes.keys where !currentIDs.contains(id) {
            attackNodes.removeValue(forKey: id)?.container.removeFromParent()
        }

        for attack in attacks {
            let nodes = attackNodes[attack.id] ?? makeAttackNodes(for: attack)
            attackNodes[attack.id] = nodes
            update(nodes, with: attack, diagnostics: diagnostics, accessibility: accessibility)
        }
    }

    private func makeAttackNodes(for attack: ArenaRenderAttack) -> AttackNodes {
        let container = SKNode()
        let telegraphCrop = SKCropNode()
        let telegraphMask = SKShapeNode()
        let telegraph = SKSpriteNode()
        let active = SKShapeNode()
        let identifier = makeLabel()
        let timing = makeLabel()

        container.name = "attack.\(attack.id)"
        telegraph.name = "attack.telegraph"
        active.name = "attack.active"
        identifier.name = "attack.identifier"
        timing.name = "attack.timing"

        telegraph.colorBlendFactor = 1
        telegraphMask.lineWidth = 0
        telegraphMask.fillColor = .white
        telegraphCrop.maskNode = telegraphMask
        telegraphCrop.zPosition = -20
        telegraphCrop.addChild(telegraph)

        container.addChild(telegraphCrop)
        container.addChild(active)
        container.addChild(identifier)
        container.addChild(timing)
        attackLayer.addChild(container)

        return AttackNodes(
            container: container,
            telegraphCrop: telegraphCrop,
            telegraphMask: telegraphMask,
            telegraph: telegraph,
            active: active,
            identifier: identifier,
            timing: timing
        )
    }

    private func update(
        _ nodes: AttackNodes,
        with attack: ArenaRenderAttack,
        diagnostics: DiagnosticsOptions,
        accessibility: ArenaAccessibilityOptions
    ) {
        let telegraphStyle = catalog.style(for: .attackTelegraph, accessibility: accessibility)
        let activeStyle = catalog.style(for: .attackActive, accessibility: accessibility)

        nodes.container.position = attack.origin
        nodes.telegraph.color = telegraphStyle.fillColor
        apply(activeStyle, to: nodes.active)

        switch attack.shape {
        case let .sweep(sweep):
            updateSweep(nodes, with: attack, sweep: sweep, accessibility: accessibility)
        case let .shot(shot):
            updateShot(
                nodes,
                with: attack,
                shot: shot,
                activeStyle: activeStyle,
                accessibility: accessibility
            )
        }

        nodes.active.zPosition = -10
        nodes.active.isHidden = attack.phase != .active

        nodes.identifier.text = "\(attack.id) • \(attack.sourceEntityID)"
        nodes.identifier.position = CGPoint(x: 0, y: attack.reach + 24)
        nodes.identifier.isHidden = !(diagnostics.isEnabled && diagnostics.showsAttackIdentifiers)

        nodes.timing.text = "\(attack.phase.rawValue) \(Int(attack.phaseProgress * 100))%"
        nodes.timing.position = CGPoint(x: 0, y: attack.reach + 48)
        nodes.timing.isHidden = !(diagnostics.isEnabled && diagnostics.showsPhaseTiming)
    }

    private func updateSweep(
        _ nodes: AttackNodes,
        with attack: ArenaRenderAttack,
        sweep: ArenaRenderAttack.Sweep,
        accessibility: ArenaAccessibilityOptions
    ) {
        // The blade always travels from the telegraph's start angle to its
        // end angle. Nothing drew that before, so a wedge that reads
        // identically at both ends was hiding the one fact the player most
        // needs. The fill is densest where the blade begins and thins toward
        // where it lands, and the outline is left open on that leading side,
        // so direction survives both greyscale and Differentiate Without
        // Colour — it is carried by shape and density, not hue.
        let span = sweep.telegraphEndAngle - sweep.telegraphStartAngle
        nodes.telegraph.texture = telegraphTextures.texture(
            for: .sweep(arcDegrees: Double(span) * 180 / .pi),
            increaseContrast: accessibility.increaseContrast
        )
        nodes.telegraph.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // The texture draws its own radius as a fraction of its side, so the
        // sprite is sized from that rather than from the reach directly.
        let extent = attack.reach / TelegraphTextureCache.radiusFraction
        nodes.telegraph.size = CGSize(width: extent, height: extent)
        // The texture is drawn centred on its own zero angle, so rotating to
        // the arc's midpoint lands its dense end on the swing's start.
        nodes.telegraph.zRotation =
            (sweep.telegraphStartAngle + sweep.telegraphEndAngle) / 2
        // Mirroring across the arc's own axis swaps which edge is dense
        // without a second texture: the ramp is symmetric in everything but
        // direction, which is the one thing being flipped.
        nodes.telegraph.yScale = sweep.isReversed ? -1 : 1

        // Ground the blade has already crossed is safe, so the warning is
        // clipped to what it has not reached yet and the swing appears to
        // push it along. Leaving the full wedge lit through the active phase
        // marked ground that could no longer hurt anyone, which is worse than
        // showing nothing — it teaches the player to distrust the warning.
        // A reversed blade eats its arc from the far edge inward, so the
        // ground still to come is on the other side of it.
        let survivingStart: CGFloat
        let survivingEnd: CGFloat
        if attack.phase == .telegraph {
            survivingStart = sweep.telegraphStartAngle
            survivingEnd = sweep.telegraphEndAngle
        } else if sweep.isReversed {
            survivingStart = sweep.telegraphStartAngle
            survivingEnd = min(sweep.telegraphEndAngle, sweep.activeStartAngle)
        } else {
            survivingStart = max(sweep.telegraphStartAngle, sweep.activeEndAngle)
            survivingEnd = sweep.telegraphEndAngle
        }
        nodes.telegraphMask.path = survivingStart < survivingEnd
            ? sectorPath(
                reach: attack.reach,
                startAngle: survivingStart,
                endAngle: survivingEnd
            )
            : CGMutablePath()

        nodes.active.path = sectorPath(
            reach: attack.reach,
            startAngle: sweep.activeStartAngle,
            endAngle: sweep.activeEndAngle
        )

        // The warning used to breathe, from a time when an even wedge had no
        // other way to draw attention. The gradient does that work now, and a
        // pulse on top of it only fought the shape it was meant to sell — so
        // the telegraph holds steady and the blade clearing it is the only
        // motion in the warning.
        nodes.telegraph.alpha = attack.phase == .telegraph ? 1 : 0.55
    }

    private func updateShot(
        _ nodes: AttackNodes,
        with attack: ArenaRenderAttack,
        shot: ArenaRenderAttack.Shot,
        activeStyle: PresentationStyle,
        accessibility: ArenaAccessibilityOptions
    ) {
        // The lane texture is drawn running along +X from its left edge, so
        // the sprite is anchored at the muzzle and simply turned to the axis.
        let spriteHalfHeight = shot.halfWidth / TelegraphTextureCache.laneWidthFraction
        nodes.telegraph.texture = telegraphTextures.texture(
            for: .lane,
            increaseContrast: accessibility.increaseContrast
        )
        nodes.telegraph.anchorPoint = CGPoint(x: 0, y: 0.5)
        nodes.telegraph.size = CGSize(
            width: attack.reach,
            height: spriteHalfHeight * 2
        )
        nodes.telegraph.zRotation = shot.axisAngle
        nodes.telegraph.yScale = 1

        // Lane the bolt has already crossed is safe, exactly as with the
        // sweep's arc. A blocked shot clears the whole lane at once: the rest
        // of it will never be travelled, and leaving it lit would mark ground
        // nothing can reach.
        let survivingFrom: CGFloat = attack.phase == .telegraph
            ? 0
            : shot.noseDistance
        nodes.telegraphMask.path = shot.isBlocked || attack.phase == .recovery
            ? CGMutablePath()
            : lanePath(
                from: survivingFrom,
                to: attack.reach,
                halfHeight: spriteHalfHeight,
                angle: shot.axisAngle
            )

        // The bolt itself: a short capsule at the nose, drawn from the same
        // distances the simulation advanced.
        nodes.active.path = lanePath(
            from: shot.tailDistance,
            to: shot.noseDistance,
            halfHeight: shot.halfWidth,
            angle: shot.axisAngle,
            cornerRadius: shot.halfWidth
        )
        // The role's fill alpha is tuned for a sector nearly two hundred
        // points across. A bolt is a twenty-eight-point capsule, and at the
        // same alpha it reads as a smudge on the dark floor — so it takes the
        // role's colour at full strength. The catalog still owns the hue;
        // only the coverage it is compensating for differs.
        nodes.active.fillColor = activeStyle.fillColor

        // Unlike the sweep, the lane ahead of a travelling bolt is not a
        // leftover warning — it is where the bolt will be in a fraction of a
        // second, so it stays at full strength until the shot is spent.
        nodes.telegraph.alpha = attack.phase == .recovery ? 0.55 : 1
    }

    /// A rectangle laid along an axis from the attack's origin, in the
    /// container's unrotated space.
    private func lanePath(
        from: CGFloat,
        to: CGFloat,
        halfHeight: CGFloat,
        angle: CGFloat,
        cornerRadius: CGFloat = 0
    ) -> CGPath {
        guard to > from, halfHeight > 0 else { return CGMutablePath() }
        var transform = CGAffineTransform(rotationAngle: angle)
        let rect = CGRect(
            x: from,
            y: -halfHeight,
            width: to - from,
            height: halfHeight * 2
        )
        guard cornerRadius > 0 else {
            return CGPath(rect: rect, transform: &transform)
        }
        return CGPath(
            roundedRect: rect,
            cornerWidth: min(cornerRadius, rect.width / 2),
            cornerHeight: min(cornerRadius, rect.height / 2),
            transform: &transform
        )
    }

    private func updateImpacts(
        _ impacts: [ArenaRenderImpact],
        accessibility: ArenaAccessibilityOptions
    ) {
        for impact in impacts where renderedImpactIDs.insert(impact.id).inserted {
            let role: PresentationRole = impact.kind == .friendlyFire
                ? .friendlyFireImpact
                : .playerDamageImpact
            let style = catalog.style(for: role, accessibility: accessibility)
            let node = SKShapeNode(path: impactPath(for: impact.kind))

            node.name = "impact.\(impact.id)"
            node.position = impact.position
            apply(style, to: node)
            node.zPosition = 12
            impactLayer.addChild(node)

            // The discovery hit is the loudest effect in the game: a longer,
            // larger burst plus an expanding ring (static ring under Reduce
            // Motion) so the teaching moment cannot be missed.
            let duration = impact.isEmphasized ? 1.1 : 0.55
            let targetScale: CGFloat = impact.isEmphasized ? 3.4 : 1.8
            let fade = SKAction.fadeOut(
                withDuration: accessibility.reduceMotion ? 0.35 : duration
            )
            let action: SKAction
            if accessibility.reduceMotion {
                action = fade
            } else {
                action = .group([fade, .scale(to: targetScale, duration: duration)])
            }
            node.run(.sequence([action, .removeFromParent()]))

            if impact.isEmphasized {
                let ring = SKShapeNode(circleOfRadius: 30)
                ring.name = "impact.ring.\(impact.id)"
                ring.position = impact.position
                ring.fillColor = .clear
                ring.strokeColor = style.strokeColor
                ring.lineWidth = max(4, style.lineWidth)
                ring.zPosition = 11
                impactLayer.addChild(ring)

                if accessibility.reduceMotion {
                    ring.setScale(2.4)
                    ring.run(.sequence([
                        .fadeOut(withDuration: 0.9),
                        .removeFromParent(),
                    ]))
                } else {
                    ring.run(.sequence([
                        .group([
                            .scale(to: 4.5, duration: 1.0),
                            .fadeOut(withDuration: 1.0),
                        ]),
                        .removeFromParent(),
                    ]))
                }
            }
        }

        if renderedImpactIDs.count > 512 {
            renderedImpactIDs = Set(impacts.map(\.id))
        }
    }

    private func updateDebugVectors(
        _ vectors: [ArenaRenderVector],
        diagnostics: DiagnosticsOptions,
        accessibility: ArenaAccessibilityOptions
    ) {
        diagnosticsLayer.childNode(withName: "debug.vectors")?.removeFromParent()
        guard diagnostics.isEnabled else { return }

        let container = SKNode()
        container.name = "debug.vectors"
        diagnosticsLayer.addChild(container)

        for vector in vectors where shouldShow(vector.kind, diagnostics: diagnostics) {
            let role = presentationRole(for: vector.kind)
            let style = catalog.style(for: role, accessibility: accessibility)
            let node = SKShapeNode(path: arrowPath(from: vector.start, to: vector.end))
            node.name = "debug.vector.\(vector.id)"
            apply(style, to: node)
            node.zPosition = 24
            container.addChild(node)
        }
    }

    private func apply(_ style: PresentationStyle, to node: SKShapeNode) {
        node.fillColor = style.fillColor.withAlphaComponent(style.fillAlpha)
        node.strokeColor = style.strokeColor
        node.lineWidth = style.lineWidth
    }

    private func makeLabel() -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 30
        return label
    }

    private func sectorPath(
        reach: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: point(distance: reach, angle: startAngle))
        path.addArc(
            center: .zero,
            radius: reach,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }


    private func impactPath(for kind: ArenaRenderImpact.Kind) -> CGPath {
        let path = CGMutablePath()
        switch kind {
        case .playerDamage:
            path.move(to: CGPoint(x: -22, y: -22))
            path.addLine(to: CGPoint(x: 22, y: 22))
            path.move(to: CGPoint(x: 22, y: -22))
            path.addLine(to: CGPoint(x: -22, y: 22))
        case .friendlyFire:
            path.move(to: CGPoint(x: 0, y: 30))
            path.addLine(to: CGPoint(x: 10, y: 10))
            path.addLine(to: CGPoint(x: 30, y: 0))
            path.addLine(to: CGPoint(x: 10, y: -10))
            path.addLine(to: CGPoint(x: 0, y: -30))
            path.addLine(to: CGPoint(x: -10, y: -10))
            path.addLine(to: CGPoint(x: -30, y: 0))
            path.addLine(to: CGPoint(x: -10, y: 10))
            path.closeSubpath()
        }
        return path
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 14
        path.move(to: end)
        path.addLine(to: point(from: end, distance: arrowLength, angle: angle + .pi * 0.8))
        path.move(to: end)
        path.addLine(to: point(from: end, distance: arrowLength, angle: angle - .pi * 0.8))
        return path
    }

    private func point(distance: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
    }

    private func point(
        from origin: CGPoint,
        distance: CGFloat,
        angle: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: origin.x + cos(angle) * distance,
            y: origin.y + sin(angle) * distance
        )
    }

    private func shouldShow(
        _ kind: ArenaRenderVector.Kind,
        diagnostics: DiagnosticsOptions
    ) -> Bool {
        switch kind {
        case .intendedPath:
            diagnostics.showsIntentPaths
        case .resolvedPath:
            diagnostics.showsResolvedPaths
        case .collisionNormal:
            diagnostics.showsCollisionNormals
        case .pursuit:
            diagnostics.showsPursuitVectors
        }
    }

    private func presentationRole(for kind: ArenaRenderVector.Kind) -> PresentationRole {
        switch kind {
        case .intendedPath:
            .intendedPath
        case .resolvedPath:
            .resolvedPath
        case .collisionNormal:
            .collisionNormal
        case .pursuit:
            .pursuitVector
        }
    }
}

private extension ArenaRenderer {
    final class EntityNodes {
        let container: SKNode
        let body: SKSpriteNode
        let hurtbox: SKShapeNode
        let facingMarker: SKShapeNode
        let identifier: SKLabelNode
        var previousHitPoints: Int

        init(
            container: SKNode,
            body: SKSpriteNode,
            hurtbox: SKShapeNode,
            facingMarker: SKShapeNode,
            identifier: SKLabelNode,
            previousHitPoints: Int
        ) {
            self.container = container
            self.body = body
            self.hurtbox = hurtbox
            self.facingMarker = facingMarker
            self.identifier = identifier
            self.previousHitPoints = previousHitPoints
        }
    }

    final class AttackNodes {
        let container: SKNode
        /// Clips the warning to the ground the blade has not reached yet.
        let telegraphCrop: SKCropNode
        /// The mask driving that clip: a sector covering only what is still
        /// dangerous.
        let telegraphMask: SKShapeNode
        /// One sprite carrying the whole warning — gradient and tapering arc
        /// baked into a cached texture, rotated to face the swing. The shape
        /// never varies at runtime, so drawing it as geometry every frame was
        /// paying per-attack for something constant.
        let telegraph: SKSpriteNode
        let active: SKShapeNode
        let identifier: SKLabelNode
        let timing: SKLabelNode

        init(
            container: SKNode,
            telegraphCrop: SKCropNode,
            telegraphMask: SKShapeNode,
            telegraph: SKSpriteNode,
            active: SKShapeNode,
            identifier: SKLabelNode,
            timing: SKLabelNode
        ) {
            self.container = container
            self.telegraphCrop = telegraphCrop
            self.telegraphMask = telegraphMask
            self.telegraph = telegraph
            self.active = active
            self.identifier = identifier
            self.timing = timing
        }
    }
}
