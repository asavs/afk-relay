import SwiftUI

struct WalletBankView: View {
    let availableTokens: Int64

    var body: some View {
        DiagnosticPanel {
            VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                Label("Movement Bank", systemImage: "shoeprints.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(availableTokens, format: .number.grouping(.automatic))
                    .font(.largeTitle)
                    .bold()
                    .monospacedDigit()

                Text("tokens available")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Movement Bank")
        .accessibilityValue("\(availableTokens.formatted(.number.grouping(.automatic))) tokens available")
        .accessibilityIdentifier("movement-bank")
    }
}
