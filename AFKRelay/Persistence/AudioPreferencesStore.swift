import Foundation

/// UserDefaults is appropriate here because these are replaceable preferences,
/// never authoritative economy or player-progress state.
@MainActor
final class AudioPreferencesStore {
    private enum Key {
        static let musicEnabled = "audio.musicEnabled"
        static let soundEffectsEnabled = "audio.soundEffectsEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AudioSettings {
        AudioSettings(
            musicEnabled: value(forKey: Key.musicEnabled, default: true),
            soundEffectsEnabled: value(
                forKey: Key.soundEffectsEnabled,
                default: true
            )
        )
    }

    func save(_ settings: AudioSettings) {
        defaults.set(settings.musicEnabled, forKey: Key.musicEnabled)
        defaults.set(
            settings.soundEffectsEnabled,
            forKey: Key.soundEffectsEnabled
        )
    }

    private func value(forKey key: String, default defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}
