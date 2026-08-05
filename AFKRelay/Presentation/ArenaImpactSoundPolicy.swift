import Foundation

/// Collapses simultaneous impacts into a clean, semantic sound mix.
/// Visual impacts remain one-per-event; only their audio is de-cluttered.
enum ArenaImpactSoundPolicy {
    static func roles(
        for impacts: [ArenaRenderImpact]
    ) -> [PresentationSoundRole] {
        var roles: [PresentationSoundRole] = []

        if impacts.contains(where: { $0.kind == .playerDamage }) {
            roles.append(.playerDamageImpact)
        }

        let friendlyFire = impacts.filter { $0.kind == .friendlyFire }
        if friendlyFire.contains(where: \.isDefeat) {
            roles.append(.friendlyFireDefeat)
        } else if friendlyFire.contains(where: \.isEmphasized) {
            roles.append(.friendlyFireDiscovery)
        } else if friendlyFire.isEmpty == false {
            roles.append(.friendlyFireImpact)
        }

        return roles
    }
}
