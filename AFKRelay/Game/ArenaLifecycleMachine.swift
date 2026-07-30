import GameplayKit

enum ArenaActivityPhase: Equatable {
    case ready
    case running
    case paused
}

final class ArenaLifecycleMachine {
    private(set) var phase: ArenaActivityPhase = .ready

    private lazy var stateMachine = GKStateMachine(states: [
        ReadyState(owner: self),
        RunningState(owner: self),
        PausedState(owner: self),
    ])

    init() {
        stateMachine.enter(ReadyState.self)
    }

    func start() {
        stateMachine.enter(RunningState.self)
    }

    func pause() {
        stateMachine.enter(PausedState.self)
    }

    func resume() {
        stateMachine.enter(RunningState.self)
    }

    fileprivate func setPhase(_ phase: ArenaActivityPhase) {
        self.phase = phase
    }
}

private class ArenaActivityState: GKState {
    weak var owner: ArenaLifecycleMachine?

    init(owner: ArenaLifecycleMachine) {
        self.owner = owner
    }
}

private final class ReadyState: ArenaActivityState {
    override func didEnter(from previousState: GKState?) {
        owner?.setPhase(.ready)
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == RunningState.self
    }
}

private final class RunningState: ArenaActivityState {
    override func didEnter(from previousState: GKState?) {
        owner?.setPhase(.running)
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == PausedState.self
    }
}

private final class PausedState: ArenaActivityState {
    override func didEnter(from previousState: GKState?) {
        owner?.setPhase(.paused)
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == RunningState.self
    }
}
