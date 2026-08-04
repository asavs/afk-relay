import Foundation

/// Player-owned presentation preferences. These never enter simulation or
/// economy state, and music remains independently controllable from cues.
nonisolated struct AudioSettings: Equatable, Sendable {
    var musicEnabled: Bool
    var soundEffectsEnabled: Bool

    static let enabled = AudioSettings(
        musicEnabled: true,
        soundEffectsEnabled: true
    )
}
