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
                        "Open System Settings",
                        systemImage: "gear",
                        action: onOpenSystemSettings
                    )
                } header: {
                    Text("Steps")
                } footer: {
                    Text("If no step data is readable, review AFK Relay’s access in Settings and try again.")
                }

                DiagnosticsSettingsView(options: $diagnostics)

                Section("Accessibility") {
                    Label(
                        "Text, contrast, color differentiation, and reduced motion follow your system settings.",
                        systemImage: "accessibility"
                    )
                }

                Section("About this build") {
                    LabeledContent("Presentation", value: "Diagnostic primitives")
                    LabeledContent("Economy", value: "1 step = 1 token")
                    LabeledContent("Storage", value: "On this iPhone")
                }
            }
            .navigationTitle(isRunActive ? "Paused" : "Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("game-settings")
    }
}
