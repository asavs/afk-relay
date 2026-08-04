import SpriteKit

@MainActor
protocol ArenaPresentationCatalog: AnyObject {
    /// A stable presentation-resource identifier, useful for diagnostics and
    /// catalog-substitution verification. It is never a gameplay identifier.
    var catalogIdentifier: String { get }

    func style(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> PresentationStyle

    /// Repeated entity bodies use cached textures so normal arena rendering
    /// does not create one vector draw call per entity.
    func entityTexture(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> SKTexture

    /// Non-positional music and feedback audio. A catalog may return `nil`
    /// for a deliberately silent treatment.
    func soundFileName(for role: PresentationSoundRole) -> String?
}
