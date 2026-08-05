import AVFAudio
import Testing
@testable import AFKRelay

@Suite("Presentation sound player")
@MainActor
struct PresentationSoundPlayerTests {
    @Test("Audio explicitly follows the silent switch")
    func ambientAudioSession() {
        _ = PresentationSoundPlayer(catalog: DiagnosticCatalog())

        #expect(AVAudioSession.sharedInstance().category == .ambient)
    }
}
