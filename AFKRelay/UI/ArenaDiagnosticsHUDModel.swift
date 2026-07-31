import Foundation

struct ArenaDiagnosticsHUDModel: Equatable, Sendable {
    let fixedStepHz: Int
    let renderedFramesPerSecond: Int
    let simulationTick: UInt64
    let livingEnemies: Int
    let activeAttacks: Int
}
