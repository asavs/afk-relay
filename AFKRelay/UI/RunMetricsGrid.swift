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
                    // Survival is the run's headline; the counting stats
                    // share the second row.
                    GridRow {
                        survived
                            .gridCellColumns(2)
                    }
                    GridRow {
                        defeats
                        spent
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
            systemImage: "stopwatch"
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
            title: "Steps spent",
            value: model.tokensSpent.formatted(),
            systemImage: "shoeprints.fill"
        )
    }
}
