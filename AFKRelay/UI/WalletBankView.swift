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
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("steps banked")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Movement Bank")
        .accessibilityValue("\(availableTokens.formatted(.number.grouping(.automatic))) steps banked")
        .accessibilityIdentifier("movement-bank")
    }
}
