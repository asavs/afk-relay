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
            "Step bank is current"
        case .noReadableStepData:
            "No readable step data"
        case .recoverableFailure:
            "Couldn’t refresh steps"
        case .persistenceBlocked:
            "Movement is paused"
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
            "AFK Relay could not find a readable step total. Steps access may be off, or Apple Health may not have recorded steps yet."
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
