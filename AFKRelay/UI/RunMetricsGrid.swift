import SwiftUI

struct RunMetricsGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: RunSummaryModel

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AFKRelayUIStyle.compactSpacing) {
                    survived
                    defeats
                    spent
                    reward
                }
            } else {
                Grid(horizontalSpacing: AFKRelayUIStyle.compactSpacing) {
                    GridRow {
                        survived
                        defeats
                    }
                    GridRow {
                        spent
                        reward
                    }
                }
            }
        }
    }

    private var survived: some View {
        RunMetricView(
            title: "Survived",
            value: Duration.seconds(model.survivalDuration)
                .formatted(.time(pattern: .minuteSecond)),
            systemImage: "timer"
        )
    }

    private var defeats: some View {
        RunMetricView(
            title: "Enemy defeats",
            value: model.friendlyFireDefeats.formatted(),
            systemImage: "burst.fill"
        )
    }

    private var spent: some View {
        RunMetricView(
            title: "Tokens spent",
            value: model.tokensSpent.formatted(),
            systemImage: "shoeprints.fill"
        )
    }

    private var reward: some View {
        RunMetricView(
            title: "Reward",
            value: "Records only",
            systemImage: "chart.line.uptrend.xyaxis"
        )
    }
}
