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
                }
            } else {
                Grid(
                    horizontalSpacing: AFKRelayUIStyle.compactSpacing,
                    verticalSpacing: AFKRelayUIStyle.compactSpacing
                ) {
                    GridRow {
                        survived
                        defeats
                    }
                    GridRow {
                        spent
                            .gridCellColumns(2)
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
            title: "Enemies baited",
            value: model.friendlyFireDefeats.formatted(),
            systemImage: "target"
        )
    }

    private var spent: some View {
        RunMetricView(
            title: "Tokens spent",
            value: model.tokensSpent.formatted(),
            systemImage: "shoeprints.fill"
        )
    }
}
