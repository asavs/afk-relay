import SwiftUI

struct RunMetricView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        DiagnosticPanel {
            VStack(alignment: .leading, spacing: AFKRelayUIStyle.compactSpacing) {
                Label(title, systemImage: systemImage)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
