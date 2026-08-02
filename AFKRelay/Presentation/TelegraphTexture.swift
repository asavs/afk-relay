import CoreGraphics
import SpriteKit
import UIKit

/// The shape an attack's warning takes.
///
/// Every telegraph is a static image whose only per-attack variable is its
/// rotation, so each case is drawn once and reused for every enemy that
/// throws it. New attack shapes arrive as new cases; the renderer does not
/// learn anything about them beyond asking for a texture.
nonisolated enum TelegraphShape: Hashable {
    /// A blade crossing `arcDegrees`, densest where it begins and dissolving
    /// where it lands, so the direction of travel is legible before it moves.
    case sweep(arcDegrees: Double)
}

/// Bakes telegraph shapes into cached textures.
///
/// Drawn white with the shape carried entirely in the alpha channel, so the
/// presentation catalog still owns colour — the renderer tints a sprite
/// rather than the texture baking a palette in.
final class TelegraphTextureCache {
    struct Key: Hashable {
        let shape: TelegraphShape
        let increaseContrast: Bool
    }

    /// The drawn radius as a fraction of the texture's side. The remainder is
    /// margin, so the arc's stroke has somewhere to sit without clipping.
    static let radiusFraction: CGFloat = 0.46

    private static let side = 768

    private var textures: [Key: SKTexture] = [:]

    func texture(
        for shape: TelegraphShape,
        increaseContrast: Bool
    ) -> SKTexture {
        let key = Key(shape: shape, increaseContrast: increaseContrast)
        if let existing = textures[key] {
            return existing
        }
        let texture = Self.render(key)
        textures[key] = texture
        return texture
    }

    private static func render(_ key: Key) -> SKTexture {
        switch key.shape {
        case let .sweep(arcDegrees):
            renderSweep(
                arcDegrees: arcDegrees,
                increaseContrast: key.increaseContrast
            )
        }
    }

    /// Evaluated per pixel rather than assembled from wedges: a fan of
    /// wedges is what this replaces, and at texture-bake time there is no
    /// reason to approximate something the angle gives exactly.
    private static func renderSweep(
        arcDegrees: Double,
        increaseContrast: Bool
    ) -> SKTexture {
        let side = Self.side
        let center = Double(side) / 2
        let radius = Double(side) * Double(radiusFraction)
        let halfArc = arcDegrees / 2 * .pi / 180

        // Stroke weight at the trailing edge, tapering to a hairline. Higher
        // contrast asks for a heavier line, matching how the catalog treats
        // every other role.
        let strokePeak = increaseContrast ? 26.0 : 18.0
        let fillPeak = increaseContrast ? 0.92 : 0.72

        var pixels = [UInt8](repeating: 0, count: side * side * 4)

        for y in 0..<side {
            for x in 0..<side {
                let dx = Double(x) + 0.5 - center
                // Texture space runs top-down; flip so positive angles turn
                // the same way the simulation's do.
                let dy = center - (Double(y) + 0.5)
                let distance = (dx * dx + dy * dy).squareRoot()
                let angle = atan2(dy, dx)

                guard abs(angle) <= halfArc else { continue }

                // 0 where the blade starts, 1 where it lands.
                let travelled = (angle + halfArc) / (2 * halfArc)
                let remaining = 1 - travelled

                var alpha = 0.0
                if distance <= radius {
                    alpha = fillPeak * pow(remaining, 1.6)
                }

                let halfStroke = strokePeak * (0.06 + 0.94 * pow(remaining, 1.3)) / 2
                let edgeDistance = abs(distance - radius)
                if edgeDistance <= halfStroke {
                    // Feather the last texel so the arc does not alias.
                    let softness = min(1, (halfStroke - edgeDistance) / 1.5)
                    alpha = max(alpha, pow(remaining, 1.1) * softness)
                }

                guard alpha > 0 else { continue }
                let value = UInt8(min(255, max(0, alpha * 255)))
                let offset = (y * side + x) * 4
                // Premultiplied white: colour arrives from the sprite's tint.
                pixels[offset] = value
                pixels[offset + 1] = value
                pixels[offset + 2] = value
                pixels[offset + 3] = value
            }
        }

        let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        guard let image = context?.makeImage() else {
            return SKTexture()
        }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }
}
