import SpriteKit

final class ArenaScene: SKScene {
    private let lifecycle = ArenaLifecycleMachine()
    private let worldNode = SKNode()
    private let arenaBorder = SKShapeNode()
    private let playerNode = SKSpriteNode(
        color: SKColor(red: 0.23, green: 0.95, blue: 1.0, alpha: 1),
        size: CGSize(width: 30, height: 30)
    )

    override init() {
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }

        addChild(worldNode)

        arenaBorder.strokeColor = SKColor(red: 0.18, green: 0.55, blue: 0.68, alpha: 1)
        arenaBorder.lineWidth = 2
        arenaBorder.glowWidth = 1
        arenaBorder.zPosition = -1
        worldNode.addChild(arenaBorder)

        playerNode.name = "player"
        playerNode.zPosition = 1
        worldNode.addChild(playerNode)

        let title = SKLabelNode(text: "EXP IRL")
        title.name = "scaffoldTitle"
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 24
        title.fontColor = SKColor(red: 0.23, green: 0.95, blue: 1.0, alpha: 1)
        title.verticalAlignmentMode = .center
        worldNode.addChild(title)

        layoutArena()
        lifecycle.start()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutArena()
    }

    func setApplicationActive(_ isActive: Bool) {
        if isActive {
            lifecycle.resume()
            isPaused = false
        } else {
            lifecycle.pause()
            isPaused = true
        }
    }

    private func layoutArena() {
        let inset: CGFloat = 28
        let arenaFrame = frame.insetBy(dx: inset, dy: inset)
        arenaBorder.path = CGPath(rect: arenaFrame, transform: nil)
        playerNode.position = CGPoint(x: frame.midX, y: frame.midY)

        childNode(withName: "//scaffoldTitle")?.position = CGPoint(
            x: frame.midX,
            y: frame.maxY - 64
        )
    }
}
