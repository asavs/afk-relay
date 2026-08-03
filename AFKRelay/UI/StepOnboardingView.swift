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
                            .accessibilityAddTraits(.isHeader)

                        Text("Every step you walk is banked. Spend steps to survive the arena.")
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
                            Label("1 step walked = 1 step of movement", systemImage: "arrow.left.arrow.right.circle.fill")
                                .font(.headline)

                            Label("Your banked steps stay on this iPhone", systemImage: "iphone")

                            Label("AFK Relay reads your step count and nothing else", systemImage: "lock.shield.fill")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    DiagnosticPanel {
                        WalletRefreshStatusView(state: refreshState)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(AFKRelayUIStyle.screenPadding)
            }
            .scrollIndicators(.automatic)
            // Scoped before the toolbar joins so it cannot cascade over it.
            .accessibilityIdentifier("step-onboarding")
        }
        .foregroundStyle(.white)
        .toolbar(.hidden, for: .navigationBar)
        // Onboarding follows the system splash pattern: a labeled,
        // full-width primary action pinned at the bottom of the content —
        // bottom bars are icon-only territory and a first-run CTA needs
        // its words.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                if showsSettingsAction {
                    Button(
                        "Open Apple Health",
                        systemImage: "arrow.up.forward.app",
                        action: onOpenSettings
                    )
                    .afkChromeButtonStyle()
                    .controlSize(.large)
                    // Identified rather than matched by label, so wording can
                    // change without breaking the device scenarios.
                    .accessibilityIdentifier("open-health-access")
                }

                Button(action: primaryAction) {
                    if refreshState == .refreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Checking steps")
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(
                            refreshState == .idle ? "Connect Steps" : "Try Again",
                            systemImage: refreshState == .idle
                                ? "figure.walk"
                                : "arrow.clockwise"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: AFKRelayUIStyle.minimumTapTarget)
                    }
                }
                .afkChromeButtonStyle(prominent: true)
                .disabled(refreshState == .refreshing)
                .accessibilityIdentifier("connect-steps")
            }
            .padding(.horizontal, AFKRelayUIStyle.screenPadding)
            .padding(.bottom, AFKRelayUIStyle.compactSpacing)
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
