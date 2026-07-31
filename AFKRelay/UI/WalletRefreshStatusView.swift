import SwiftUI

struct WalletRefreshStatusView: View {
    let state: WalletRefreshPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
            Label {
                Text(state.title)
            } icon: {
                if state == .refreshing {
                    // A real indeterminate indicator: correctly announced
                    // and automatically honors Reduce Motion.
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: state.systemImage)
                }
            }
            .foregroundStyle(statusStyle)

            if case let .current(lastUpdated) = state, let lastUpdated {
                // Clamp to now: an observation instant can never read as the
                // future, even under a skewed or frozen clock.
                Text("Updated \(min(lastUpdated, .now), format: .relative(presentation: .named))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let recoveryMessage = state.recoveryMessage {
                Text(recoveryMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusStyle: Color {
        switch state {
        case .current:
            AFKRelayUIStyle.success
        case .recoverableFailure, .persistenceBlocked:
            AFKRelayUIStyle.warning
        case .idle, .refreshing, .noReadableStepData:
            .primary
        }
    }
}
