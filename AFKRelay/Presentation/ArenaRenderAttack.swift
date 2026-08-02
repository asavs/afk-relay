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

    /// A rotating sector: the arc it will cross, and the blade currently
    /// crossing it.
    struct Sweep: Equatable, Sendable {
        let telegraphStartAngle: CGFloat
        let telegraphEndAngle: CGFloat
        let activeStartAngle: CGFloat
        let activeEndAngle: CGFloat
        /// Whether the blade crosses its arc from the high angle down. The
        /// warning's gradient has to point the way the blade actually goes.
        let isReversed: Bool
    }

    /// A translating segment: the lane it will cross, and the bolt currently
    /// crossing it. Distances run along the axis from the muzzle.
    struct Shot: Equatable, Sendable {
        let axisAngle: CGFloat
        let halfWidth: CGFloat
        /// Where the nose is now. The lane behind it has been crossed and is
        /// no longer dangerous.
        let noseDistance: CGFloat
        let tailDistance: CGFloat
        /// Set once something stopped the bolt short of its full range, so
        /// the renderer can clear a lane that will never be travelled.
        let isBlocked: Bool
    }

    /// Which primitive this attack is. Presentation branches here and nowhere
    /// else, so a new primitive costs one case rather than a new pipeline.
    enum Shape: Equatable, Sendable {
        case sweep(Sweep)
        case shot(Shot)
    }

    let id: String
    let sourceEntityID: String
    let origin: CGPoint
    /// How far the attack reaches from its origin — a sweep's radius or a
    /// shot's full lane length.
    let reach: CGFloat
    let shape: Shape
    let phase: Phase
    let phaseProgress: Double

    init(
        id: String,
        sourceEntityID: String,
        origin: CGPoint,
        reach: CGFloat,
        shape: Shape,
        phase: Phase,
        phaseProgress: Double
    ) {
        self.id = id
        self.sourceEntityID = sourceEntityID
        self.origin = origin
        self.reach = max(0, reach)
        self.shape = shape
        self.phase = phase
        self.phaseProgress = min(max(phaseProgress, 0), 1)
    }
}
