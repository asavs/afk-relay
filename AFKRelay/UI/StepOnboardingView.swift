import SwiftUI

struct StepOnboardingView: View {
    let refreshState: WalletRefreshPresentationState
    let onConnectSteps: @MainActor () -> Void
    let onRetry: @MainActor () -> Void
    let onOpenSettings: @MainActor () -> Void

    var body: some View {
        ZStack {
            DiagnosticBackdropView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AFKRelayUIStyle.generousSpacing) {
                    OnboardingMarkView()

                    VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                        Text("Turn Steps Into Movement")
                            .font(.largeTitle)
                            .bold()
                            .multilineTextAlignment(.center)

                        Text("AFK Relay reads your step total from Apple Health. One eligible step adds exactly one movement token.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Connect Steps asks iOS for read-only Steps access. iOS shows its native Health sheet when a choice is still needed.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    DiagnosticPanel {
                        VStack(alignment: .leading, spacing: AFKRelayUIStyle.standardSpacing) {
                            Label("1 step = 1 movement token", systemImage: "equal.circle.fill")
                                .font(.headline)

                            Label("Your bank stays on this iPhone", systemImage: "iphone.gen3")

                            Label("Only your cumulative step total is used", systemImage: "lock.shield.fill")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    WalletRefreshStatusView(state: refreshState)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    OnboardingActionsView(
                        refreshState: refreshState,
                        onConnectSteps: onConnectSteps,
                        onRetry: onRetry,
                        onOpenSettings: onOpenSettings
                    )
                }
                .padding(AFKRelayUIStyle.screenPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .accessibilityIdentifier("step-onboarding")
    }
}
