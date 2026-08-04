import AVFAudio
import Foundation

/// Plays shell-level presentation cues that must outlive or sit outside the
/// SpriteKit scene, such as SwiftUI controls and the transition after defeat.
@MainActor
final class PresentationSoundPlayer {
    private var players: [PresentationSoundRole: AVAudioPlayer] = [:]

    init(catalog: any ArenaPresentationCatalog) {
        preload(.buttonPress, from: catalog)
        preload(.gameOver, from: catalog)
    }

    func play(_ role: PresentationSoundRole) {
        guard let player = players[role] else { return }
        player.currentTime = 0
        player.play()
    }

    private func preload(
        _ role: PresentationSoundRole,
        from catalog: any ArenaPresentationCatalog
    ) {
        guard
            let fileName = catalog.soundFileName(for: role),
            let url = Bundle.main.url(forResource: fileName, withExtension: nil),
            let player = try? AVAudioPlayer(contentsOf: url)
        else {
            return
        }

        player.prepareToPlay()
        players[role] = player
    }
}
