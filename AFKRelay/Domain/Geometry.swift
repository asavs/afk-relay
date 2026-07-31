import Foundation

nonisolated struct Vector2: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
    init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
    static let zero = Vector2()
    static func +(lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func -(lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func *(lhs: Self, rhs: Double) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
    var lengthSquared: Double { x * x + y * y }
    var length: Double { lengthSquared.squareRoot() }
    var normalized: Self { let l = length; return l > 0 ? self * (1 / l) : .zero }
    func dot(_ other: Self) -> Double { x * other.x + y * other.y }
    func distance(to other: Self) -> Double { (self - other).length }
    func clamped(to rect: ArenaBounds, radius: Double = 0) -> Self {
        .init(x: min(max(x, rect.minX + radius), rect.maxX - radius), y: min(max(y, rect.minY + radius), rect.maxY - radius))
    }
}

nonisolated struct ArenaBounds: Codable, Equatable, Sendable {
    var minX: Double; var minY: Double; var maxX: Double; var maxY: Double
    init(minX: Double = 0, minY: Double = 0, maxX: Double, maxY: Double) { self.minX = minX; self.minY = minY; self.maxX = maxX; self.maxY = maxY }
}

nonisolated struct CircleObstacle: Equatable, Sendable {
    let id: Int
    let center: Vector2
    let radius: Double
}

nonisolated struct SweptCircleResult: Equatable, Sendable {
    let position: Vector2
    let traveledDistance: Double
    let collisionNormals: [Vector2]
}

/// Deterministic kinematic circle movement with bounded sliding.
///
/// SpriteKit physics never participates in this calculation. Each iteration
/// advances to the earliest analytic contact, projects only the remaining
/// displacement onto the contact tangent, and records the actual path length.
nonisolated enum SweptCircleSolver {
    static func solve(
        start: Vector2,
        displacement: Vector2,
        radius: Double,
        bounds: ArenaBounds,
        obstacles: [CircleObstacle],
        maximumSlidingIterations: Int = 3
    ) -> SweptCircleResult {
        let epsilon = 0.000_001
        var position = start.clamped(to: bounds, radius: radius)
        var remaining = displacement
        var traveledDistance = 0.0
        var normals: [Vector2] = []

        for _ in 0...max(0, maximumSlidingIterations) {
            guard remaining.length > epsilon else { break }

            guard let contact = earliestContact(
                from: position,
                displacement: remaining,
                radius: radius,
                bounds: bounds,
                obstacles: obstacles
            ) else {
                position = position + remaining
                traveledDistance += remaining.length
                remaining = .zero
                break
            }

            let travel = remaining * contact.time
            position = position + travel
            traveledDistance += travel.length
            normals.append(contact.normal)

            let leftover = remaining * (1 - contact.time)
            let inwardDistance = leftover.dot(contact.normal)
            remaining = inwardDistance < 0
                ? leftover - contact.normal * inwardDistance
                : leftover
        }

        return SweptCircleResult(
            position: position.clamped(to: bounds, radius: radius),
            traveledDistance: traveledDistance,
            collisionNormals: normals
        )
    }

    private static func earliestContact(
        from start: Vector2,
        displacement: Vector2,
        radius: Double,
        bounds: ArenaBounds,
        obstacles: [CircleObstacle]
    ) -> Contact? {
        var contacts = boundaryContacts(
            from: start,
            displacement: displacement,
            radius: radius,
            bounds: bounds
        )

        contacts += obstacles.compactMap {
            circleContact(
                from: start,
                displacement: displacement,
                radius: radius,
                obstacle: $0
            )
        }

        return contacts.min {
            if abs($0.time - $1.time) > 0.000_000_001 {
                return $0.time < $1.time
            }
            return $0.order < $1.order
        }
    }

    private static func boundaryContacts(
        from start: Vector2,
        displacement: Vector2,
        radius: Double,
        bounds: ArenaBounds
    ) -> [Contact] {
        let minX = bounds.minX + radius
        let maxX = bounds.maxX - radius
        let minY = bounds.minY + radius
        let maxY = bounds.maxY - radius
        var contacts: [Contact] = []

        if displacement.x < 0, start.x + displacement.x < minX {
            contacts.append(
                Contact(
                    time: clampedTime((minX - start.x) / displacement.x),
                    normal: Vector2(x: 1, y: 0),
                    order: Int.min
                )
            )
        } else if displacement.x > 0, start.x + displacement.x > maxX {
            contacts.append(
                Contact(
                    time: clampedTime((maxX - start.x) / displacement.x),
                    normal: Vector2(x: -1, y: 0),
                    order: Int.min + 1
                )
            )
        }

        if displacement.y < 0, start.y + displacement.y < minY {
            contacts.append(
                Contact(
                    time: clampedTime((minY - start.y) / displacement.y),
                    normal: Vector2(x: 0, y: 1),
                    order: Int.min + 2
                )
            )
        } else if displacement.y > 0, start.y + displacement.y > maxY {
            contacts.append(
                Contact(
                    time: clampedTime((maxY - start.y) / displacement.y),
                    normal: Vector2(x: 0, y: -1),
                    order: Int.min + 3
                )
            )
        }

        return contacts
    }

    private static func circleContact(
        from start: Vector2,
        displacement: Vector2,
        radius: Double,
        obstacle: CircleObstacle
    ) -> Contact? {
        let expandedRadius = max(0, radius) + max(0, obstacle.radius)
        let offset = start - obstacle.center
        let a = displacement.lengthSquared
        guard a > 0.000_000_000_001 else { return nil }

        let c = offset.lengthSquared - expandedRadius * expandedRadius
        let approach = offset.dot(displacement)

        // Exact contact while separating or moving tangentially is not a new
        // collision; accepting it avoids sticky surfaces during sliding.
        if c >= -0.000_001, approach >= -0.000_001 {
            return nil
        }

        let discriminant = approach * approach - a * c
        guard discriminant >= 0 else { return nil }

        let time = (-approach - discriminant.squareRoot()) / a
        guard time >= -0.000_001, time <= 1.000_001 else { return nil }

        let clamped = clampedTime(time)
        let contactPosition = start + displacement * clamped
        var normal = (contactPosition - obstacle.center).normalized
        if normal.lengthSquared == 0 {
            normal = (displacement * -1).normalized
        }

        return Contact(time: clamped, normal: normal, order: obstacle.id)
    }

    private static func clampedTime(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private struct Contact {
        let time: Double
        let normal: Vector2
        let order: Int
    }
}
