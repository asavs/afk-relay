import Foundation

struct RunSummaryModel: Equatable, Sendable {
    let survivalDuration: TimeInterval
    let friendlyFireDefeats: Int
    let tokensSpent: Int64
    let bestSurvivalDuration: TimeInterval
    let bestFriendlyFireDefeats: Int
    let isNewSurvivalBest: Bool
    let isNewFriendlyFireBest: Bool

    init(
        survivalDuration: TimeInterval,
        friendlyFireDefeats: Int,
        tokensSpent: Int64,
        bestSurvivalDuration: TimeInterval,
        bestFriendlyFireDefeats: Int,
        isNewSurvivalBest: Bool,
        isNewFriendlyFireBest: Bool
    ) {
        self.survivalDuration = max(0, survivalDuration)
        self.friendlyFireDefeats = max(0, friendlyFireDefeats)
        self.tokensSpent = max(0, tokensSpent)
        self.bestSurvivalDuration = max(0, bestSurvivalDuration)
        self.bestFriendlyFireDefeats = max(0, bestFriendlyFireDefeats)
        self.isNewSurvivalBest = isNewSurvivalBest
        self.isNewFriendlyFireBest = isNewFriendlyFireBest
    }
}
