import Testing
@testable import AFKRelay

@Suite("AFK Relay smoke checks")
struct AFKRelayTests {
    @Test("SpriteKit advances the game at sixty fixed steps per second")
    @MainActor
    func fixedStepCadence() {
        #expect(ArenaScene.fixedStepDuration == 1.0 / 60.0)
        #expect(ArenaScene.maximumCatchUpSteps > 0)
    }
}
