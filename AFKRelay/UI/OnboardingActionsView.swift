import SwiftUI

struct OnboardingActionsView: View {
    let refreshState: WalletRefreshPresentationState
    let onConnectSteps: @MainActor () -> Void
    let onRetry: @MainActor () -> Void
    let onOpenSettings: @MainActor () -> Void

    var body: some View {
        VStack(spacing: AFKRelayUIStyle.compactSpacing) {
            Button(
                refreshState == .idle ? "Connect Steps" : "Try Again",
                systemImage: refreshState == .idle ? "heart.text.square.fill" : "arrow.clockwise",
                action: primaryAction
            )
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(refreshState == .refreshing)
            .frame(minHeight: AFKRelayUIStyle.minimumTapTarget)
            .accessibilityIdentifier("connect-steps")

            if showsSettingsAction {
                Button(
                    "Review Steps Access",
                    systemImage: "gear",
                    action: onOpenSettings
                )
                    .buttonStyle(.bordered)
                    .frame(minHeight: AFKRelayUIStyle.minimumTapTarget)
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
