import CoreGraphics
import Foundation

/// Framework-facing entity data copied from an authoritative gameplay snapshot.
/// It contains no movement, collision, attack, or damage rules.
struct ArenaRenderEntity: Identifiable, Equatable, Sendable {
    let id: String
    let role: PresentationRole
    let position: CGPoint
    let radius: CGFloat
    let facingAngle: CGFloat
    let hitPoints: Int
    let maximumHitPoints: Int

    init(
        id: String,
        role: PresentationRole,
        position: CGPoint,
        radius: CGFloat,
        facingAngle: CGFloat,
        hitPoints: Int,
        maximumHitPoints: Int
    ) {
        precondition(
            role == .playerBody
                || role == .enemyBody
                || role == .enemyBodyWounded
        )
        self.id = id
        self.role = role
        self.position = position
        self.radius = max(0, radius)
        self.facingAngle = facingAngle
        self.maximumHitPoints = max(1, maximumHitPoints)
        self.hitPoints = min(max(0, hitPoints), self.maximumHitPoints)
    }
}
