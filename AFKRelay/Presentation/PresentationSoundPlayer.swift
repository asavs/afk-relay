import AVFAudio
import Foundation

/// Plays shell-level presentation cues that must outlive or sit outside the
/// SpriteKit scene, such as SwiftUI controls and the transition after defeat.
@MainActor
final class PresentationSoundPlayer {
    private static let musicVolume: Float = 0.34
    private static let musicFadeInDuration: TimeInterval = 0.8
    private static let musicFadeOutDuration: TimeInterval = 0.35

    private var effectPlayers: [PresentationSoundRole: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var settings: AudioSettings
    private var lobbyMusicIsActive = false
    private var applicationIsActive = true
    private var musicPauseTask: Task<Void, Never>?

    init(
        catalog: any ArenaPresentationCatalog,
        settings: AudioSettings = .enabled
    ) {
        Self.configureAudioSession()
        self.settings = settings
        effectPlayers[.buttonPress] = makePlayer(.buttonPress, from: catalog)
        effectPlayers[.gameOver] = makePlayer(.gameOver, from: catalog)
        musicPlayer = makePlayer(.lobbyMusic, from: catalog)
        musicPlayer?.numberOfLoops = -1
        musicPlayer?.volume = 0
    }

    /// Game audio is complementary rather than essential: it follows the
    /// Ring/Silent switch and mixes with audio the player already has running.
    private static func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient,
            mode: .default
        )
    }

    func play(_ role: PresentationSoundRole) {
        guard settings.soundEffectsEnabled,
              let player = effectPlayers[role]
        else {
            return
        }
        player.currentTime = 0
        player.play()
    }

    func update(settings: AudioSettings) {
        self.settings = settings
        synchronizeMusic()
    }

    func setLobbyMusicActive(_ isActive: Bool) {
        lobbyMusicIsActive = isActive
        synchronizeMusic()
    }

    func setApplicationActive(_ isActive: Bool) {
        applicationIsActive = isActive
        synchronizeMusic()
    }

    private func makePlayer(
        _ role: PresentationSoundRole,
        from catalog: any ArenaPresentationCatalog
    ) -> AVAudioPlayer? {
        guard
            let fileName = catalog.soundFileName(for: role),
            let url = Bundle.main.url(forResource: fileName, withExtension: nil),
            let player = try? AVAudioPlayer(contentsOf: url)
        else {
            return nil
        }

        player.prepareToPlay()
        return player
    }

    private func synchronizeMusic() {
        guard let musicPlayer else { return }
        let shouldPlay = settings.musicEnabled
            && lobbyMusicIsActive
            && applicationIsActive

        musicPauseTask?.cancel()
        musicPauseTask = nil

        if shouldPlay {
            if !musicPlayer.isPlaying {
                musicPlayer.play()
            }
            musicPlayer.setVolume(
                Self.musicVolume,
                fadeDuration: Self.musicFadeInDuration
            )
        } else if musicPlayer.isPlaying {
            musicPlayer.setVolume(
                0,
                fadeDuration: Self.musicFadeOutDuration
            )
            musicPauseTask = Task { [weak self, weak musicPlayer] in
                try? await Task.sleep(
                    for: .seconds(Self.musicFadeOutDuration)
                )
                guard !Task.isCancelled,
                      let self,
                      let musicPlayer,
                      !self.shouldPlayMusic
                else {
                    return
                }
                musicPlayer.pause()
            }
        }
    }

    private var shouldPlayMusic: Bool {
        settings.musicEnabled && lobbyMusicIsActive && applicationIsActive
    }
}
