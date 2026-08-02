import Foundation

enum WalletRefreshPresentationState: Equatable, Sendable {
    case idle
    case refreshing
    case current(lastUpdated: Date?)
    case noReadableStepData
    case recoverableFailure(message: String)
    case persistenceBlocked(message: String)

    var title: String {
        switch self {
        case .idle:
            "Ready to check steps"
        case .refreshing:
            "Checking steps…"
        case .current:
            "Movement bank is up to date"
        case .noReadableStepData:
            "No step data yet"
        case .recoverableFailure:
            "Couldn’t refresh steps"
        case .persistenceBlocked:
            "Couldn’t save your bank"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            "arrow.clockwise"
        case .refreshing:
            "progress.indicator"
        case .current:
            "checkmark.circle.fill"
        case .noReadableStepData:
            "shoeprints.fill"
        case .recoverableFailure:
            "exclamationmark.triangle.fill"
        case .persistenceBlocked:
            "exclamationmark.triangle.fill"
        }
    }

    var recoveryMessage: String? {
        switch self {
        case let .recoverableFailure(message), let .persistenceBlocked(message):
            message
        case .noReadableStepData:
            // Apple Health reports nothing the same way whether access is off
            // or the day is simply empty, so this cannot claim which it is.
            // It says what is true and where the answer lives — the Health
            // app, since Steps access never appears on the app's own Settings
            // page and looking for it there is a dead end.
            "AFK Relay can’t find any steps. Either none are recorded yet, or it can’t read them — check Health › Sharing › Apps › AFK Relay."
        case .idle, .refreshing, .current:
            nil
        }
    }

    var permitsManualRetry: Bool {
        switch self {
        case .refreshing:
            false
        case .idle, .current, .noReadableStepData, .recoverableFailure, .persistenceBlocked:
            true
        }
    }
}
