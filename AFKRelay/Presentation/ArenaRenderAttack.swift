import CoreGraphics
import Foundation

/// Geometry already selected and advanced by the simulation. The renderer only
/// converts these angles and distances into visible paths.
struct ArenaRenderAttack: Identifiable, Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case telegraph
        case active
        case recovery
    }

    let id: String
    let sourceEntityID: String
    let origin: CGPoint
    let reach: CGFloat
    let telegraphStartAngle: CGFloat
    let telegraphEndAngle: CGFloat
    let activeStartAngle: CGFloat
    let activeEndAngle: CGFloat
    /// Whether the blade crosses its arc from the high angle down. The
    /// warning's gradient has to point the way the blade actually goes.
    let isReversed: Bool
    let phase: Phase
    let phaseProgress: Double

    init(
        id: String,
        sourceEntityID: String,
        origin: CGPoint,
        reach: CGFloat,
        telegraphStartAngle: CGFloat,
        telegraphEndAngle: CGFloat,
        activeStartAngle: CGFloat,
        activeEndAngle: CGFloat,
        isReversed: Bool = false,
        phase: Phase,
        phaseProgress: Double
    ) {
        self.id = id
        self.sourceEntityID = sourceEntityID
        self.origin = origin
        self.reach = max(0, reach)
        self.telegraphStartAngle = telegraphStartAngle
        self.telegraphEndAngle = telegraphEndAngle
        self.activeStartAngle = activeStartAngle
        self.activeEndAngle = activeEndAngle
        self.isReversed = isReversed
        self.phase = phase
        self.phaseProgress = min(max(phaseProgress, 0), 1)
    }
}
