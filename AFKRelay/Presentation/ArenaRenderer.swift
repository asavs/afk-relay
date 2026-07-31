import SpriteKit

/// Incremental SpriteKit renderer for immutable presentation snapshots.
///
/// `ArenaRenderer` never advances time or mutates gameplay state. Its only
/// authority is the node tree it owns.
@MainActor
final class ArenaRenderer {
    let rootNode = SKNode()

    private let catalog: any ArenaPresentationCatalog
    private let boundaryNode = SKShapeNode()
    private let attackLayer = SKNode()
    private let entityLayer = SKNode()
    private let impactLayer = SKNode()
    private let diagnosticsLayer = SKNode()
    private var entityNodes: [String: EntityNodes] = [:]
    private var attackNodes: [String: AttackNodes] = [:]
    private var renderedImpactIDs: Set<String> = []
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

        updateBoundary(accessibility: accessibility)
        updateEntities(snapshot.entities, diagnostics: options, accessibility: accessibility)
        updateAttacks(snapshot.attacks, diagnostics: options, accessibility: accessibility)
        updateImpacts(snapshot.impacts, accessibility: accessibility)
        updateDebugVectors(snapshot.debugVectors, diagnostics: options, accessibility: accessibility)
        updateMetrics(snapshot.diagnostics, diagnostics: options, accessibility: accessibility)
    }

    private func configureNodeTree() {
        rootNode.name = "presentation.root"
        rootNode.addChild(boundaryNode)
        rootNode.addChild(attackLayer)
        rootNode.addChild(entityLayer)
        rootNode.addChild(impactLayer)
        rootNode.addChild(diagnosticsLayer)

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

    private func updateBoundary(accessibility: ArenaAccessibilityOptions) {
        let style = catalog.style(for: .arenaBoundary, accessibility: accessibility)
        boundaryNode.path = CGPath(
            rect: CGRect(origin: .zero, size: arenaSize),
            transform: nil
        )
        apply(style, to: boundaryNode)
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
            update(nodes, with: entity, diagnostics: diagnostics, accessibility: accessibility)
        }
    }

    private func makeEntityNodes(for entity: ArenaRenderEntity) -> EntityNodes {
        let container = SKNode()
        let body = SKSpriteNode()
        let hurtbox = SKShapeNode()
        let facingMarker = SKShapeNode()
        let healthBackground = SKSpriteNode(color: .black, size: .zero)
        let healthFill = SKSpriteNode(color: .white, size: .zero)
        let identifier = makeLabel()

        container.name = "entity.\(entity.id)"
        body.name = "entity.body"
        hurtbox.name = "entity.hurtbox"
        facingMarker.name = "entity.facing"
        healthBackground.name = "entity.health.background"
        healthFill.name = "entity.health.fill"
        identifier.name = "entity.identifier"

        healthBackground.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthFill.anchorPoint = CGPoint(x: 0, y: 0.5)

        container.addChild(hurtbox)
        container.addChild(body)
        container.addChild(facingMarker)
        container.addChild(healthBackground)
        container.addChild(healthFill)
        container.addChild(identifier)
        entityLayer.addChild(container)

        return EntityNodes(
            container: container,
            body: body,
            hurtbox: hurtbox,
            facingMarker: facingMarker,
            healthBackground: healthBackground,
            healthFill: healthFill,
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

        let healthWidth = max(42, diameter)
        let healthHeight = max(7, diameter * 0.09)
        let healthPosition = CGPoint(x: -healthWidth / 2, y: entity.radius + 18)
        nodes.healthBackground.position = healthPosition
        nodes.healthBackground.size = CGSize(width: healthWidth, height: healthHeight)
        nodes.healthBackground.zPosition = 4
        nodes.healthFill.position = healthPosition
        nodes.healthFill.size = CGSize(width: healthWidth, height: healthHeight)
        nodes.healthFill.color = bodyStyle.fillColor
        nodes.healthFill.xScale = CGFloat(entity.hitPoints) / CGFloat(entity.maximumHitPoints)
        nodes.healthFill.zPosition = 5

        nodes.identifier.text = entity.id
        nodes.identifier.position = CGPoint(x: 0, y: -(entity.radius + 28))
        nodes.identifier.isHidden = !(diagnostics.isEnabled && diagnostics.showsEntityIdentifiers)

        if entity.hitPoints < nodes.previousHitPoints {
            showDamageFeedback(on: nodes.body, reduceMotion: accessibility.reduceMotion)
        }
        nodes.previousHitPoints = entity.hitPoints
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
        let telegraph = SKShapeNode()
        let active = SKShapeNode()
        let cueLines = SKShapeNode()
        let identifier = makeLabel()
        let timing = makeLabel()

        container.name = "attack.\(attack.id)"
        telegraph.name = "attack.telegraph"
        active.name = "attack.active"
        cueLines.name = "attack.non-color-cues"
        identifier.name = "attack.identifier"
        timing.name = "attack.timing"

        container.addChild(telegraph)
        container.addChild(active)
        container.addChild(cueLines)
        container.addChild(identifier)
        container.addChild(timing)
        attackLayer.addChild(container)

        return AttackNodes(
            container: container,
            telegraph: telegraph,
            active: active,
            cueLines: cueLines,
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
        nodes.telegraph.path = sectorPath(
            reach: attack.reach,
            startAngle: attack.telegraphStartAngle,
            endAngle: attack.telegraphEndAngle
        )
        apply(telegraphStyle, to: nodes.telegraph)
        nodes.telegraph.zPosition = -20

        nodes.active.path = sectorPath(
            reach: attack.reach,
            startAngle: attack.activeStartAngle,
            endAngle: attack.activeEndAngle
        )
        apply(activeStyle, to: nodes.active)
        nodes.active.zPosition = -10
        nodes.active.isHidden = attack.phase != .active

        nodes.telegraph.alpha = switch attack.phase {
        case .telegraph: 1
        case .active: 0.55
        case .recovery: 0.2
        }

        nodes.cueLines.path = attackCuePath(for: attack)
        nodes.cueLines.strokeColor = attack.phase == .active
            ? activeStyle.strokeColor
            : telegraphStyle.strokeColor
        nodes.cueLines.lineWidth = max(3, telegraphStyle.lineWidth * 0.75)
        nodes.cueLines.zPosition = -9

        nodes.identifier.text = "\(attack.id) • \(attack.sourceEntityID)"
        nodes.identifier.position = CGPoint(x: 0, y: attack.reach + 24)
        nodes.identifier.isHidden = !(diagnostics.isEnabled && diagnostics.showsAttackIdentifiers)

        nodes.timing.text = "\(attack.phase.rawValue) \(Int(attack.phaseProgress * 100))%"
        nodes.timing.position = CGPoint(x: 0, y: attack.reach + 48)
        nodes.timing.isHidden = !(diagnostics.isEnabled && diagnostics.showsPhaseTiming)
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

            let fade = SKAction.fadeOut(withDuration: accessibility.reduceMotion ? 0.35 : 0.55)
            let action: SKAction
            if accessibility.reduceMotion {
                action = fade
            } else {
                action = .group([fade, .scale(to: 1.8, duration: 0.55)])
            }
            node.run(.sequence([action, .removeFromParent()]))
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

    private func updateMetrics(
        _ metrics: ArenaDiagnosticsMetrics?,
        diagnostics: DiagnosticsOptions,
        accessibility: ArenaAccessibilityOptions
    ) {
        diagnosticsLayer.childNode(withName: "debug.metrics")?.removeFromParent()
        guard diagnostics.isEnabled,
              diagnostics.showsFrameMetrics,
              let metrics
        else {
            return
        }

        let style = catalog.style(for: .diagnosticText, accessibility: accessibility)
        let label = makeLabel()
        label.name = "debug.metrics"
        label.text = "SIM \(metrics.fixedStepHz)Hz  RENDER \(metrics.renderedFramesPerSecond)fps  E \(metrics.livingEnemyCount)  A \(metrics.activeAttackCount)  T \(metrics.simulationTick)"
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: 16, y: arenaSize.height - 32)
        label.fontColor = style.fillColor
        label.zPosition = 30
        diagnosticsLayer.addChild(label)
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

    private func attackCuePath(for attack: ArenaRenderAttack) -> CGPath {
        let path = CGMutablePath()
        let middle = (attack.telegraphStartAngle + attack.telegraphEndAngle) / 2
        let inset = attack.reach * 0.18

        for angle in [
            attack.telegraphStartAngle,
            middle,
            attack.telegraphEndAngle,
        ] {
            path.move(to: point(distance: inset, angle: angle))
            path.addLine(to: point(distance: attack.reach, angle: angle))
        }
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
        let healthBackground: SKSpriteNode
        let healthFill: SKSpriteNode
        let identifier: SKLabelNode
        var previousHitPoints: Int

        init(
            container: SKNode,
            body: SKSpriteNode,
            hurtbox: SKShapeNode,
            facingMarker: SKShapeNode,
            healthBackground: SKSpriteNode,
            healthFill: SKSpriteNode,
            identifier: SKLabelNode,
            previousHitPoints: Int
        ) {
            self.container = container
            self.body = body
            self.hurtbox = hurtbox
            self.facingMarker = facingMarker
            self.healthBackground = healthBackground
            self.healthFill = healthFill
            self.identifier = identifier
            self.previousHitPoints = previousHitPoints
        }
    }

    final class AttackNodes {
        let container: SKNode
        let telegraph: SKShapeNode
        let active: SKShapeNode
        let cueLines: SKShapeNode
        let identifier: SKLabelNode
        let timing: SKLabelNode

        init(
            container: SKNode,
            telegraph: SKShapeNode,
            active: SKShapeNode,
            cueLines: SKShapeNode,
            identifier: SKLabelNode,
            timing: SKLabelNode
        ) {
            self.container = container
            self.telegraph = telegraph
            self.active = active
            self.cueLines = cueLines
            self.identifier = identifier
            self.timing = timing
        }
    }
}
