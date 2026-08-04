import SwiftUI

struct GameSettingsView: View {
    @Binding var diagnostics: DiagnosticsOptions
    @Binding var audioSettings: AudioSettings

    let refreshState: WalletRefreshPresentationState
    let onRefreshSteps: @MainActor () -> Void
    let onOpenSystemSettings: @MainActor () -> Void
    let onDone: @MainActor () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WalletRefreshStatusView(state: refreshState)

                    Button(
                        "Refresh Steps",
                        systemImage: "arrow.clockwise",
                        action: onRefreshSteps
                    )
                    .disabled(!refreshState.permitsManualRetry)

                    Button(
                        "Open Apple Health",
                        systemImage: "arrow.up.forward.app",
                        action: onOpenSystemSettings
                    )
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Not seeing your steps? Steps access lives in Health › Sharing › Apps › AFK Relay, not in this app’s Settings page.")
                }

                Section("Audio") {
                    Toggle(isOn: $audioSettings.musicEnabled) {
                        Label("Music", systemImage: "music.note")
                    }
                    .accessibilityIdentifier("music-enabled")

                    Toggle(isOn: $audioSettings.soundEffectsEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2")
                    }
                    .accessibilityIdentifier("sound-effects-enabled")
                }

                DiagnosticsSettingsView(options: $diagnostics)

                Section {
                    LabeledContent("Version", value: Self.buildDescription)
                        .accessibilityIdentifier("build-version")
                    LabeledContent("Movement", value: "1 step walked = 1 step of movement")
                    LabeledContent("Your data", value: "Stays on this iPhone")
                } header: {
                    Text("About This Build")
                } footer: {
                    Text("Text size, contrast, Differentiate Without Color, and Reduce Motion all follow your iPhone settings.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .accessibilityIdentifier("game-settings")
    }

    /// Marketing version and build number, as Apple records them in the
    /// bundle. The build number is the part that distinguishes two installs
    /// of the same version, which is exactly the question a tester on a
    /// development build needs answered — "is this the one you just gave
    /// me?" was unanswerable from inside the app before this.
    private static var buildDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
