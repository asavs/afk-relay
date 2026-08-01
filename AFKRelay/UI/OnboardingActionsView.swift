import SwiftUI

struct OnboardingActionsView: View {
    let refreshState: WalletRefreshPresentationState
    let onConnectSteps: @MainActor () -> Void
    let onRetry: @MainActor () -> Void
    let onOpenSettings: @MainActor () -> Void

    var body: some View {
        VStack(spacing: AFKRelayUIStyle.compactSpacing) {
            Button(action: primaryAction) {
                if refreshState == .refreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Checking steps")
                } else {
                    Label(
                        refreshState == .idle ? "Connect Steps" : "Try Again",
                        systemImage: refreshState == .idle
                            ? "figure.walk"
                            : "arrow.clockwise"
                    )
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(refreshState == .refreshing)
            .accessibilityIdentifier("connect-steps")

            if showsSettingsAction {
                Button(
                    "Review Steps Access",
                    systemImage: "arrow.up.forward.app",
                    action: onOpenSettings
                )
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
    }

    private var showsSettingsAction: Bool {
        switch refreshState {
        case .recoverableFailure, .noReadableStepData, .persistenceBlocked:
            true
        case .idle, .refreshing, .current:
            false
        }
    }

    private func primaryAction() {
        if refreshState == .idle {
            onConnectSteps()
        } else {
            onRetry()
        }
    }
}
