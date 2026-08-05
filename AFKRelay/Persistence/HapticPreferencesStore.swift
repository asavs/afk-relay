import Foundation

/// Haptics are a replaceable presentation preference, never authoritative
/// simulation, economy, or player-progress state.
@MainActor
final class HapticPreferencesStore {
    private static let enabledKey = "haptics.enabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Bool {
        guard defaults.object(forKey: Self.enabledKey) != nil else {
            return true
        }
        return defaults.bool(forKey: Self.enabledKey)
    }

    func save(isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.enabledKey)
    }
}
