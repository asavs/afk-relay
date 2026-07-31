import SwiftUI

struct WalletRefreshStatusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: WalletRefreshPresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
            Label(state.title, systemImage: state.systemImage)
                .symbolEffect(
                    .rotate,
                    isActive: state == .refreshing && !reduceMotion
                )
                .foregroundStyle(statusStyle)

            if case let .current(lastUpdated) = state, let lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
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
