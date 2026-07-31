import CoreGraphics
import Foundation

struct ArenaRenderSnapshot: Equatable, Sendable {
    let arenaSize: CGSize
    let entities: [ArenaRenderEntity]
    let attacks: [ArenaRenderAttack]
    let impacts: [ArenaRenderImpact]
    let debugVectors: [ArenaRenderVector]
    let diagnostics: ArenaDiagnosticsMetrics?

    init(
        arenaSize: CGSize = CGSize(width: 1000, height: 1500),
        entities: [ArenaRenderEntity],
        attacks: [ArenaRenderAttack],
        impacts: [ArenaRenderImpact] = [],
        debugVectors: [ArenaRenderVector] = [],
        diagnostics: ArenaDiagnosticsMetrics? = nil
    ) {
        self.arenaSize = arenaSize
        self.entities = entities
        self.attacks = attacks
        self.impacts = impacts
        self.debugVectors = debugVectors
        self.diagnostics = diagnostics
    }
}
