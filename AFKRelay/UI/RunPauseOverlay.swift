import SwiftUI

struct RunPauseOverlay: View {
    let onResume: @MainActor () -> Void
    let onShowSettings: @MainActor () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            DiagnosticPanel {
                VStack(spacing: AFKRelayUIStyle.standardSpacing) {
                    Label("Run Paused", systemImage: "pause.circle.fill")
                        .font(.title)
                        .bold()

                    Button("Resume", systemImage: "play.fill", action: onResume)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                    Button("Settings", systemImage: "gearshape", action: onShowSettings)
                        .buttonStyle(.bordered)
                }
            }
            .padding(AFKRelayUIStyle.screenPadding)
        }
        .foregroundStyle(.white)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("run-paused")
    }
}
