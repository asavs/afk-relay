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
            "externaldrive.badge.exclamationmark"
        }
    }

    var recoveryMessage: String? {
        switch self {
        case let .recoverableFailure(message), let .persistenceBlocked(message):
            message
        case .noReadableStepData:
            "AFK Relay hasn’t been able to read a step total. Check that AFK Relay can read Steps in Settings, then try again."
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
