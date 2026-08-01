import Foundation

struct ArenaHUDModel: Equatable, Sendable {
    let availableTokens: Int64
    let runStartingTokens: Int64
    let playerHealth: Int
    let maximumPlayerHealth: Int
    let survivalDuration: TimeInterval
    let tokensSpentThisRun: Int64
    let refreshState: WalletRefreshPresentationState

    init(
        availableTokens: Int64,
        runStartingTokens: Int64,
        playerHealth: Int,
        maximumPlayerHealth: Int,
        survivalDuration: TimeInterval,
        tokensSpentThisRun: Int64,
        refreshState: WalletRefreshPresentationState
    ) {
        self.availableTokens = max(0, availableTokens)
        self.runStartingTokens = max(1, runStartingTokens)
        self.maximumPlayerHealth = max(1, maximumPlayerHealth)
        self.playerHealth = min(max(0, playerHealth), self.maximumPlayerHealth)
        self.survivalDuration = max(0, survivalDuration)
        self.tokensSpentThisRun = max(0, tokensSpentThisRun)
        self.refreshState = refreshState
    }

    /// Stamina as a run-relative fraction: full at run start, draining as
    /// tokens burn. Mid-run walking can refill it past the start; clamp.
    var staminaFraction: Double {
        min(1, Double(availableTokens) / Double(runStartingTokens))
    }
}
