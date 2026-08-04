import SpriteKit
import UIKit

@MainActor
final class DiagnosticCatalog: ArenaPresentationCatalog {
    let catalogIdentifier = "diagnostic-primitives-v1"

    private var textureCache: [String: SKTexture] = [:]

    func soundFileName(for role: PresentationSoundRole) -> String? {
        switch role {
        case .buttonPress: "button-press.wav"
        case .gameOver: "game-over.wav"
        case .sweepTelegraph: "sweep-telegraph.wav"
        case .sweepActive: "sweep-active.wav"
        case .shotTelegraph: "shot-telegraph.wav"
        case .shotActive: "shot-active.wav"
        case .playerDamageImpact: "player-damage.wav"
        case .friendlyFireImpact: "friendly-fire.wav"
        case .friendlyFireDiscovery: "friendly-fire-discovery.wav"
        }
    }

    func style(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> PresentationStyle {
        let palette = Palette(accessibility: accessibility)

        return switch role {
        case .arenaBackground:
            // The stroke describes the floor grid; the renderer draws it
            // from this role so a future catalog can restyle or remove it.
            PresentationStyle(
                fillColor: palette.background,
                strokeColor: palette.boundary.withAlphaComponent(
                    accessibility.increaseContrast ? 0.3 : 0.16
                ),
                lineWidth: 1,
                fillAlpha: 1
            )
        case .arenaBoundary:
            PresentationStyle(
                fillColor: .clear,
                strokeColor: palette.boundary,
                lineWidth: accessibility.increaseContrast ? 7 : 4,
                fillAlpha: 0
            )
        case .playerBody:
            PresentationStyle(
                fillColor: palette.player,
                strokeColor: palette.primaryInk,
                lineWidth: accessibility.increaseContrast ? 7 : 5,
                fillAlpha: 1
            )
        case .playerHurtbox:
            PresentationStyle(
                fillColor: .clear,
                strokeColor: palette.player,
                lineWidth: accessibility.increaseContrast ? 4 : 2,
                fillAlpha: 0
            )
        case .enemyBody:
            PresentationStyle(
                fillColor: palette.enemy,
                strokeColor: palette.primaryInk,
                lineWidth: accessibility.increaseContrast ? 7 : 5,
                fillAlpha: 1
            )
        case .enemyBodyWounded:
            PresentationStyle(
                fillColor: palette.enemyWounded,
                strokeColor: palette.primaryInk,
                lineWidth: accessibility.increaseContrast ? 7 : 5,
                fillAlpha: 1
            )
        case .enemyBodyRanged:
            PresentationStyle(
                fillColor: palette.enemyRanged,
                strokeColor: palette.primaryInk,
                lineWidth: accessibility.increaseContrast ? 7 : 5,
                fillAlpha: 1
            )
        case .enemyHurtbox:
            PresentationStyle(
                fillColor: .clear,
                strokeColor: palette.enemy,
                lineWidth: accessibility.increaseContrast ? 4 : 2,
                fillAlpha: 0
            )
        case .attackTelegraph:
            PresentationStyle(
                fillColor: palette.telegraph,
                strokeColor: palette.telegraph,
                lineWidth: accessibility.increaseContrast ? 7 : 4,
                fillAlpha: accessibility.increaseContrast ? 0.28 : 0.18
            )
        case .attackActive:
            PresentationStyle(
                fillColor: palette.attack,
                strokeColor: palette.primaryInk,
                lineWidth: accessibility.increaseContrast ? 6 : 4,
                fillAlpha: accessibility.increaseContrast ? 0.72 : 0.58
            )
        case .playerDamageImpact:
            PresentationStyle(
                fillColor: .clear,
                strokeColor: palette.playerDamage,
                lineWidth: 4,
                fillAlpha: 0.9
            )
        case .friendlyFireImpact:
            PresentationStyle(
                fillColor: palette.friendlyFire,
                strokeColor: palette.primaryInk,
                lineWidth: 4,
                fillAlpha: 0.9
            )
        case .intendedPath:
            vectorStyle(color: palette.intent, accessibility: accessibility)
        case .resolvedPath:
            vectorStyle(color: palette.resolved, accessibility: accessibility)
        case .collisionNormal:
            vectorStyle(color: palette.collision, accessibility: accessibility)
        case .pursuitVector:
            vectorStyle(color: palette.pursuit, accessibility: accessibility)
        case .diagnosticText:
            PresentationStyle(
                fillColor: .white,
                strokeColor: palette.background,
                lineWidth: 1,
                fillAlpha: 1
            )
        }
    }

    func entityTexture(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> SKTexture {
        let key = [
            role.rawValue,
            accessibility.differentiateWithoutColor ? "differentiate" : "color",
            accessibility.increaseContrast ? "contrast" : "standard",
        ].joined(separator: "-")

        if let cached = textureCache[key] {
            return cached
        }

        let texture = makeEntityTexture(for: role, accessibility: accessibility)
        texture.filteringMode = .linear
        textureCache[key] = texture
        return texture
    }

    private func vectorStyle(
        color: SKColor,
        accessibility: ArenaAccessibilityOptions
    ) -> PresentationStyle {
        PresentationStyle(
            fillColor: .clear,
            strokeColor: color,
            lineWidth: accessibility.increaseContrast ? 5 : 3,
            fillAlpha: 0
        )
    }

    private func makeEntityTexture(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> SKTexture {
        let style = style(for: role, accessibility: accessibility)
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1

        let image = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.setLineWidth(style.lineWidth)
            context.setFillColor(style.fillColor.cgColor)
            context.setStrokeColor(style.strokeColor.cgColor)

            switch role {
            case .enemyBody:
                drawEnemy(in: context, accessibility: accessibility, wounded: false)
            case .enemyBodyWounded:
                drawEnemy(in: context, accessibility: accessibility, wounded: true)
            case .enemyBodyRanged:
                drawMarksman(in: context, accessibility: accessibility)
            default:
                drawPlayer(in: context, accessibility: accessibility)
            }
        }

        return SKTexture(image: image)
    }

    private func drawPlayer(
        in context: CGContext,
        accessibility: ArenaAccessibilityOptions
    ) {
        let body = CGRect(x: 12, y: 12, width: 104, height: 104)
        context.addEllipse(in: body)
        context.drawPath(using: .fillStroke)

        context.setStrokeColor(SKColor.black.cgColor)
        context.setLineWidth(accessibility.increaseContrast ? 9 : 7)
        context.move(to: CGPoint(x: 64, y: 37))
        context.addLine(to: CGPoint(x: 64, y: 91))
        context.move(to: CGPoint(x: 43, y: 64))
        context.addLine(to: CGPoint(x: 85, y: 64))
        context.strokePath()

        if accessibility.differentiateWithoutColor {
            context.setLineWidth(4)
            context.addEllipse(in: CGRect(x: 28, y: 28, width: 72, height: 72))
            context.strokePath()
        }
    }

    // A chevron aimed along the facing axis: the silhouette itself says
    // "incoming" the way a diamond never can. Texture-top is the facing
    // direction per the adapter's +Y convention.
    private func drawEnemy(
        in context: CGContext,
        accessibility: ArenaAccessibilityOptions,
        wounded: Bool
    ) {
        context.move(to: CGPoint(x: 64, y: 8))
        context.addLine(to: CGPoint(x: 118, y: 92))
        context.addLine(to: CGPoint(x: 64, y: 64))
        context.addLine(to: CGPoint(x: 10, y: 92))
        context.closePath()
        context.drawPath(using: .fillStroke)

        context.setStrokeColor(SKColor.black.cgColor)
        context.setLineWidth(accessibility.increaseContrast ? 9 : 7)
        context.move(to: CGPoint(x: 64, y: 20))
        context.addLine(to: CGPoint(x: 64, y: 56))
        context.strokePath()

        if wounded {
            // The wound reads by shape as well as tint: a jagged crack
            // through the wing.
            context.setLineWidth(accessibility.increaseContrast ? 7 : 5)
            context.move(to: CGPoint(x: 88, y: 44))
            context.addLine(to: CGPoint(x: 78, y: 60))
            context.addLine(to: CGPoint(x: 92, y: 66))
            context.addLine(to: CGPoint(x: 82, y: 84))
            context.strokePath()
        }

        if accessibility.differentiateWithoutColor {
            context.setLineWidth(3)
            for offset in stride(from: -18, through: 18, by: 12) {
                context.move(to: CGPoint(x: 52 + offset, y: 74))
                context.addLine(to: CGPoint(x: 64 + offset, y: 86))
            }
            context.strokePath()
        }
    }

    // A blunt hexagon with a barrel running out along the facing axis. It has
    // to be unmistakable against both the chevron and the player's circle at
    // a glance and at speed: the chevron's silhouette says "closing on you",
    // and this one has to say "already pointed at you from over there".
    private func drawMarksman(
        in context: CGContext,
        accessibility: ArenaAccessibilityOptions
    ) {
        context.move(to: CGPoint(x: 64, y: 20))
        context.addLine(to: CGPoint(x: 106, y: 44))
        context.addLine(to: CGPoint(x: 106, y: 84))
        context.addLine(to: CGPoint(x: 64, y: 108))
        context.addLine(to: CGPoint(x: 22, y: 84))
        context.addLine(to: CGPoint(x: 22, y: 44))
        context.closePath()
        context.drawPath(using: .fillStroke)

        // The barrel points where the lane will open.
        context.setStrokeColor(SKColor.black.cgColor)
        context.setLineWidth(accessibility.increaseContrast ? 14 : 11)
        context.move(to: CGPoint(x: 64, y: 52))
        context.addLine(to: CGPoint(x: 64, y: 120))
        context.strokePath()

        if accessibility.differentiateWithoutColor {
            // Concentric rings read as an optic, and read as nothing like the
            // chevron's hatching.
            context.setLineWidth(4)
            context.addEllipse(in: CGRect(x: 46, y: 46, width: 36, height: 36))
            context.strokePath()
        }
    }
}

private extension DiagnosticCatalog {
    struct Palette {
        let background: SKColor
        let boundary: SKColor
        let primaryInk: SKColor
        let player: SKColor
        let enemy: SKColor
        let enemyWounded: SKColor
        let enemyRanged: SKColor
        let telegraph: SKColor
        let attack: SKColor
        let playerDamage: SKColor
        let friendlyFire: SKColor
        let intent: SKColor
        let resolved: SKColor
        let collision: SKColor
        let pursuit: SKColor

        init(accessibility: ArenaAccessibilityOptions) {
            background = SKColor(red: 0.025, green: 0.035, blue: 0.065, alpha: 1)
            boundary = accessibility.increaseContrast
                ? .white
                : SKColor(red: 0.25, green: 0.70, blue: 0.82, alpha: 1)
            primaryInk = accessibility.increaseContrast
                ? .black
                : SKColor(red: 0.02, green: 0.04, blue: 0.07, alpha: 1)
            player = SKColor(red: 0.22, green: 0.95, blue: 1, alpha: 1)
            enemy = SKColor(red: 1, green: 0.35, blue: 0.46, alpha: 1)
            enemyWounded = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
            // Enemy-family, but far enough from the chevron's red that the
            // two never blur together in a crowded arena.
            enemyRanged = SKColor(red: 0.76, green: 0.44, blue: 1, alpha: 1)
            telegraph = SKColor(red: 1, green: 0.76, blue: 0.18, alpha: 1)
            attack = SKColor(red: 1, green: 0.28, blue: 0.16, alpha: 1)
            playerDamage = SKColor(red: 1, green: 0.98, blue: 0.92, alpha: 1)
            friendlyFire = SKColor(red: 0.72, green: 1, blue: 0.32, alpha: 1)
            intent = SKColor(red: 0.83, green: 0.67, blue: 1, alpha: 1)
            resolved = SKColor(red: 0.27, green: 1, blue: 0.72, alpha: 1)
            collision = SKColor(red: 1, green: 0.92, blue: 0.28, alpha: 1)
            pursuit = SKColor(red: 1, green: 0.49, blue: 0.72, alpha: 1)
        }
    }
}
