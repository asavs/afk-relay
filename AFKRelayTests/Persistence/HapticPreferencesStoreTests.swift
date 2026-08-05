import Foundation
import Testing
@testable import AFKRelay

@Suite("Haptic preferences")
@MainActor
struct HapticPreferencesStoreTests {
    @Test("Haptics default on and persist independently")
    func defaultsAndPersistence() throws {
        let suiteName = "HapticPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = HapticPreferencesStore(defaults: defaults)
        #expect(store.load())

        store.save(isEnabled: false)
        #expect(!HapticPreferencesStore(defaults: defaults).load())

        store.save(isEnabled: true)
        #expect(HapticPreferencesStore(defaults: defaults).load())
    }
}
