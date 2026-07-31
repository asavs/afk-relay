import Foundation

struct ArenaHUDModel: Equatable, Sendable {
    let availableTokens: Int64
    let playerHealth: Int
    let maximumPlayerHealth: Int
    let survivalDuration: TimeInterval
    let tokensSpentThisRun: Int64
    let refreshState: WalletRefreshPresentationState

    init(
        availableTokens: Int64,
        playerHealth: Int,
        maximumPlayerHealth: Int,
        survivalDuration: TimeInterval,
        tokensSpentThisRun: Int64,
        refreshState: WalletRefreshPresentationState
    ) {
        self.availableTokens = max(0, availableTokens)
        self.maximumPlayerHealth = max(1, maximumPlayerHealth)
        self.playerHealth = min(max(0, playerHealth), self.maximumPlayerHealth)
        self.survivalDuration = max(0, survivalDuration)
        self.tokensSpentThisRun = max(0, tokensSpentThisRun)
        self.refreshState = refreshState
    }
}
