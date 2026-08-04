import Foundation
import Testing
@testable import AFKRelay

@Suite("Audio preferences")
@MainActor
struct AudioPreferencesStoreTests {
    @Test("Music and effects default on and persist independently")
    func defaultsAndPersistence() throws {
        let suiteName = "AudioPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AudioPreferencesStore(defaults: defaults)
        #expect(store.load() == .enabled)

        store.save(
            AudioSettings(
                musicEnabled: false,
                soundEffectsEnabled: true
            )
        )
        #expect(
            AudioPreferencesStore(defaults: defaults).load()
                == AudioSettings(
                    musicEnabled: false,
                    soundEffectsEnabled: true
                )
        )

        store.save(
            AudioSettings(
                musicEnabled: true,
                soundEffectsEnabled: false
            )
        )
        #expect(
            AudioPreferencesStore(defaults: defaults).load()
                == AudioSettings(
                    musicEnabled: true,
                    soundEffectsEnabled: false
                )
        )
    }
}
