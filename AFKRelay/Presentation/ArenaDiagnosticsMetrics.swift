import Foundation

struct ArenaDiagnosticsMetrics: Equatable, Sendable {
    let fixedStepHz: Int
    let renderedFramesPerSecond: Int
    let livingEnemyCount: Int
    let activeAttackCount: Int
    let simulationTick: UInt64
}
