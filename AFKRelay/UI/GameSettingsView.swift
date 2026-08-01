import SwiftUI

struct GameSettingsView: View {
    @Binding var diagnostics: DiagnosticsOptions

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
                        "Open Settings",
                        systemImage: "arrow.up.forward.app",
                        action: onOpenSystemSettings
                    )
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Not seeing your steps? Review AFK Relay’s access in Settings, then try again.")
                }

                DiagnosticsSettingsView(options: $diagnostics)

                Section {
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
}
