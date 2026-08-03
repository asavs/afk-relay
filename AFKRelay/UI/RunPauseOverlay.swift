import SwiftUI

struct RunPauseOverlay: View {
    let onResume: @MainActor () -> Void
    let onEndRun: @MainActor () -> Void
    let onShowSettings: @MainActor () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(AFKRelayUIStyle.pauseDimOpacity)
                .ignoresSafeArea()

            DiagnosticPanel {
                VStack(spacing: AFKRelayUIStyle.standardSpacing) {
                    Label("Run Paused", systemImage: "pause.circle.fill")
                        .font(.title)
                        .bold()
                        .accessibilityAddTraits(.isHeader)

                    Button("Resume", systemImage: "play.fill", action: onResume)
                        .afkChromeButtonStyle(prominent: true)
                        .controlSize(.large)

                    Button(
                        "End Run",
                        systemImage: "stop.fill",
                        role: .destructive,
                        action: onEndRun
                    )
                    .afkChromeButtonStyle(destructiveTint: AFKRelayUIStyle.enemy)
                    .controlSize(.large)
                    .tint(AFKRelayUIStyle.enemy)
                    .accessibilityIdentifier("end-run")

                    Button("Settings", systemImage: "gearshape", action: onShowSettings)
                        .afkChromeButtonStyle()
                        .controlSize(.large)
                }
            }
            .padding(AFKRelayUIStyle.screenPadding)
        }
        .foregroundStyle(.white)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("run-paused")
    }
}
