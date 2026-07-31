import SwiftUI

struct GameSettingsView: View {
    @Binding var diagnostics: DiagnosticsOptions

    let isRunActive: Bool
    let refreshState: WalletRefreshPresentationState
    let onRefreshSteps: @MainActor () -> Void
    let onOpenSystemSettings: @MainActor () -> Void
    let onResume: @MainActor () -> Void
    let onEndRun: @MainActor () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if isRunActive {
                    Section("Run") {
                        Button("Resume", systemImage: "play.fill", action: onResume)
                        Button(
                            "End Run",
                            systemImage: "stop.fill",
                            role: .destructive,
                            action: onEndRun
                        )
                        .accessibilityIdentifier("end-run")
                    }
                }

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
                    LabeledContent("Movement", value: "1 step = 1 token")
                    LabeledContent("Your data", value: "Stays on this iPhone")
                } header: {
                    Text("About This Build")
                } footer: {
                    Text("Text size, contrast, Differentiate Without Color, and Reduce Motion all follow your iPhone settings.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("game-settings")
    }
}
