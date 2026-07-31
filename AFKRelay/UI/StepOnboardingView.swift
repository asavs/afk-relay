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

                        Text("Every step you walk becomes one movement token. Spend tokens to survive the arena.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text("Tap Connect Steps to let AFK Relay read your step count. Apple Health will ask for your permission.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    DiagnosticPanel {
                        VStack(alignment: .leading, spacing: AFKRelayUIStyle.standardSpacing) {
                            Label("1 step = 1 movement token", systemImage: "arrow.left.arrow.right.circle.fill")
                                .font(.headline)

                            Label("Your movement tokens stay on this iPhone", systemImage: "iphone")

                            Label("AFK Relay reads your step count and nothing else", systemImage: "lock.shield.fill")
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
