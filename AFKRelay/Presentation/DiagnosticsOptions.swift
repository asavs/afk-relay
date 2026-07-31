import Foundation

struct DiagnosticsOptions: Equatable, Sendable {
    var isEnabled: Bool
    var showsEntityIdentifiers: Bool
    var showsAttackIdentifiers: Bool
    var showsIntentPaths: Bool
    var showsResolvedPaths: Bool
    var showsCollisionNormals: Bool
    var showsPursuitVectors: Bool
    var showsPhaseTiming: Bool
    var showsFrameMetrics: Bool

    static let disabled = DiagnosticsOptions(
        isEnabled: false,
        showsEntityIdentifiers: false,
        showsAttackIdentifiers: false,
        showsIntentPaths: false,
        showsResolvedPaths: false,
        showsCollisionNormals: false,
        showsPursuitVectors: false,
        showsPhaseTiming: false,
        showsFrameMetrics: false
    )

    static let inspection = DiagnosticsOptions(
        isEnabled: true,
        showsEntityIdentifiers: true,
        showsAttackIdentifiers: true,
        showsIntentPaths: true,
        showsResolvedPaths: true,
        showsCollisionNormals: true,
        showsPursuitVectors: true,
        showsPhaseTiming: true,
        showsFrameMetrics: true
    )
}
