import SwiftUI

struct WalletBankView: View {
    let availableTokens: Int64

    var body: some View {
        DiagnosticPanel {
            VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                Label("Movement bank", systemImage: "shoeprints.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(availableTokens, format: .number.grouping(.automatic))
                    .font(.largeTitle)
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("tokens available")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Movement bank")
        .accessibilityValue("\(availableTokens.formatted(.number.grouping(.automatic))) tokens available")
        .accessibilityIdentifier("movement-bank")
    }
}
