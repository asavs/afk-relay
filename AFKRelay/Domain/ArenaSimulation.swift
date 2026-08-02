import Foundation

nonisolated enum ArenaTutorialStage: String, Codable, Equatable, Sendable { case moveAndEvade, friendlyFire, endless }
nonisolated enum EndlessPressurePolicy {
    static func spawnInterval(
        at endlessElapsed: Double,
        balance: MVPBalance = .v3
    ) -> Double {
        max(
            balance.spawnMinimumInterval,
            balance.spawnInitialInterval
                - (balance.spawnInitialInterval - balance.spawnMinimumInterval)
                * min(1, max(0, endlessElapsed) / balance.spawnRampDuration)
        )
    }
}
nonisolated struct EndlessSpawnScheduler: Equatable, Sendable {
    private(set) var elapsed = 0.0
    private(set) var pendingTime = 0.0

    mutating func advance(
        duration: Double,
        livingEnemyCount: Int,
        balance: MVPBalance = .v3
    ) -> Bool {
        let safeDuration = max(0, duration)
        elapsed += safeDuration
        let interval = EndlessPressurePolicy.spawnInterval(
            at: elapsed,
            balance: balance
        )

        // Retain at most one pending interval. Time spent at the living-enemy
        // cap must not become a burst-spawn backlog when capacity reopens.
        pendingTime = min(pendingTime + safeDuration, interval)
        guard
            livingEnemyCount < balance.enemyCap,
            pendingTime + 0.000_000_001 >= interval
        else {
            return false
        }

        pendingTime = 0
        return true
    }

    mutating func reset() {
        self = EndlessSpawnScheduler()
    }
}
nonisolated enum GameEvent: Equatable, Sendable {
    case spawned(Int)
    case damaged(
        target: Int,
        source: Int,
        amount: Int,
        position: Vector2
    )
    case enemyDefeated(Int)
    case playerDefeated
    case tutorialAdvanced(ArenaTutorialStage)
    case tutorialCompleted
}
nonisolated enum ArenaTutorialPolicy {
    static func shouldCompleteFriendlyFireStage(
        playerHitPoints: Int,
        playerID: Int,
        events: [GameEvent]
    ) -> Bool {
        guard playerHitPoints > 0 else { return false }
        return events.contains { event in
            guard case let .damaged(target, source, _, _) = event else {
                return false
            }
            return target != playerID && target != source
        }
    }
}
nonisolated struct ArenaEntity: Equatable, Sendable {
    let id: Int
    var position: Vector2
    var velocity: Vector2
    var facing: Vector2
    var radius: Double
    var hitPoints: Int
    var isPlayer: Bool
}
nonisolated struct ArenaAttack: Equatable, Sendable {
    let sourceID: Int
    let facing: Vector2
    /// Whether this blade crosses its arc backwards. Fixed for the life of
    /// the attack and settled when it is thrown, so the direction a player
    /// reads during the telegraph is the direction that lands.
    var isReversed = false
    var age: Double
    var playerTravelDistance: Double
    var hitIDs: Set<Int>

    func isActive(balance: MVPBalance = .v3) -> Bool {
        if case .active = SweepGeometry.phase(at: age, balance: balance) {
            return true
        }
        return false
    }

    func isFinished(balance: MVPBalance = .v3) -> Bool {
        SweepGeometry.phase(at: age, balance: balance) == .finished
    }
}
nonisolated struct ArenaRunResult: Equatable, Sendable { let survived: Bool; let elapsed: Double; let enemiesDefeated: Int; let friendlyFireDefeats: Int; let tokensSpent: Int64 }
nonisolated struct ArenaSnapshot: Equatable, Sendable {
    let elapsed: Double
    let player: ArenaEntity
    let enemies: [ArenaEntity]
    let attacks: [ArenaAttack]
    let tutorialStage: ArenaTutorialStage
    let playerCollisionNormals: [Vector2]
    let isFinished: Bool
}

nonisolated enum ArenaAttackResolver {
    static func eligibleTargetIDs(
        for attack: ArenaAttack,
        source: ArenaEntity,
        targets: [ArenaEntity],
        fromAge: Double? = nil,
        balance: MVPBalance = .v3
    ) -> [Int] {
        targets
            .filter { target in
                guard
                    target.hitPoints > 0,
                    target.id != source.id,
                    !attack.hitIDs.contains(target.id)
                else {
                    return false
                }

                if let fromAge {
                    return SweepGeometry.containsSwept(
                        targetCenter: target.position,
                        targetRadius: target.radius,
                        sourceCenter: source.position,
                        facing: attack.facing,
                        fromAge: fromAge,
                        throughAge: attack.age,
                        reversed: attack.isReversed,
                        balance: balance
                    )
                }
                return SweepGeometry.contains(
                    targetCenter: target.position,
                    targetRadius: target.radius,
                    sourceCenter: source.position,
                    facing: attack.facing,
                    age: attack.age,
                    reversed: attack.isReversed,
                    balance: balance
                )
            }
            .map(\.id)
            .sorted()
    }
}

nonisolated struct ArenaSimulation: Sendable {
    static let fixedTimeStep = 1.0 / 60.0
    let balance: MVPBalance; let bounds: ArenaBounds
    private(set) var player: ArenaEntity; private(set) var enemies: [ArenaEntity] = []; private(set) var attacks: [ArenaAttack] = []; private(set) var elapsed = 0.0; private(set) var tutorialStage: ArenaTutorialStage = .moveAndEvade; private(set) var result: ArenaRunResult?
    private var spawnScheduler = EndlessSpawnScheduler(); private var nextID = 1; private var kills = 0; private var friendlyFireKills = 0; private var movedDistance = 0.0; private var evadedTelegraph = false; private(set) var tokensSpent: Int64 = 0; private(set) var lastPlayerTravelDistance = 0.0; private(set) var lastPlayerCollisionNormals: [Vector2] = []
    init(balance: MVPBalance = .v3, tutorialCompleted: Bool = false) {
        self.balance = balance
        bounds = .init(maxX: balance.arenaSize.x, maxY: balance.arenaSize.y)
        tutorialStage = tutorialCompleted ? .endless : .moveAndEvade
        player = .init(
            id: 0,
            position: .init(
                x: balance.arenaSize.x / 2,
                y: balance.arenaSize.y / 2
            ),
            velocity: .zero,
            facing: Vector2(x: 0, y: 1),
            radius: balance.playerRadius,
            hitPoints: balance.playerHitPoints,
            isPlayer: true
        )
        _ = spawnEnemy()
    }
    var snapshot: ArenaSnapshot { .init(elapsed: elapsed, player: player, enemies: enemies, attacks: attacks, tutorialStage: tutorialStage, playerCollisionNormals: lastPlayerCollisionNormals, isFinished: result != nil) }
    mutating func reset(tutorialCompleted: Bool = false) { self = ArenaSimulation(balance: balance, tutorialCompleted: tutorialCompleted) }
    mutating func step(input: Vector2 = .zero) -> [GameEvent] { step(input: input, duration: Self.fixedTimeStep) }
    mutating func step(input: Vector2, duration: Double) -> [GameEvent] {
        precondition(abs(duration - Self.fixedTimeStep) < 0.000_001, "ArenaSimulation requires 1/60-second ticks")
        guard result == nil else {
            lastPlayerTravelDistance = 0
            lastPlayerCollisionNormals = []
            return []
        }
        var events: [GameEvent] = []; elapsed += duration
        let desired = input.length > 1 ? input.normalized : input
        player.velocity = desired * balance.playerSpeed
        if desired.length > 0 {
            player.facing = desired.normalized
        }
        let playerMovement = moveSolid(
            entity: player,
            displacement: player.velocity * duration,
            ignoringID: player.id
        )
        player.position = playerMovement.position
        lastPlayerTravelDistance = playerMovement.traveledDistance
        lastPlayerCollisionNormals = playerMovement.collisionNormals
        movedDistance += lastPlayerTravelDistance
        if lastPlayerTravelDistance > 0 {
            for index in attacks.indices {
                attacks[index].playerTravelDistance += lastPlayerTravelDistance
            }
        }
        moveEnemies(duration: duration)
        advanceAttacks(duration: duration, events: &events)
        beginEnemyAttacks()
        if tutorialStage == .endless {
            if spawnScheduler.advance(
                duration: duration,
                livingEnemyCount: enemies.count,
                balance: balance
            ) {
                if let spawnedID = spawnEnemy() {
                    events.append(.spawned(spawnedID))
                }
            }
        }
        updateTutorial(events: &events)
        if player.hitPoints <= 0 { result = .init(survived: false, elapsed: elapsed, enemiesDefeated: kills, friendlyFireDefeats: friendlyFireKills, tokensSpent: tokensSpent); events.append(.playerDefeated) }
        return events
    }
    @discardableResult
    private mutating func spawnEnemy() -> Int? {
        let radius = balance.enemyRadius
        let positions = [
            Vector2(x: radius, y: radius),
            Vector2(x: bounds.maxX - radius, y: radius),
            Vector2(x: bounds.maxX - radius, y: bounds.maxY - radius),
            Vector2(x: radius, y: bounds.maxY - radius),
        ]
        let firstIndex = max(0, nextID - 1) % positions.count
        let orderedPositions = (0..<positions.count).map {
            positions[(firstIndex + $0) % positions.count]
        }
        guard let position = orderedPositions.first(where: { candidate in
            candidate.distance(to: player.position)
                >= radius + player.radius
                && enemies.allSatisfy {
                    candidate.distance(to: $0.position) >= radius + $0.radius
                }
        }) else {
            return nil
        }

        let id = nextID
        let facing = (player.position - position).normalized
        enemies.append(
            .init(
                id: id,
                position: position,
                velocity: .zero,
                facing: facing,
                radius: radius,
                hitPoints: balance.enemyHitPoints,
                isPlayer: false
            )
        )
        nextID += 1
        return id
    }
    private mutating func moveEnemies(duration: Double) {
        for i in enemies.indices {
            let poseIsLocked = attacks.contains {
                guard $0.sourceID == enemies[i].id else { return false }
                switch SweepGeometry.phase(at: $0.age, balance: balance) {
                case .telegraph, .active:
                    return true
                case .recovery, .finished:
                    return false
                }
            }
            guard !poseIsLocked else {
                enemies[i].velocity = .zero
                continue
            }
            let toward = (player.position - enemies[i].position).normalized
            let speed = tutorialStage == .endless
                ? balance.enemySpeed
                : balance.tutorialEnemySpeed
            enemies[i].velocity = toward * speed
            if toward.length > 0 {
                enemies[i].facing = toward
            }
            let movement = moveSolid(
                entity: enemies[i],
                displacement: enemies[i].velocity * duration,
                ignoringID: enemies[i].id
            )
            enemies[i].position = movement.position
        }
    }

    private func moveSolid(
        entity: ArenaEntity,
        displacement: Vector2,
        ignoringID: Int
    ) -> SweptCircleResult {
        var obstacles = enemies
            .filter { $0.id != ignoringID && $0.hitPoints > 0 }
            .map { CircleObstacle(id: $0.id, center: $0.position, radius: $0.radius) }
        if ignoringID != player.id, player.hitPoints > 0 {
            obstacles.append(
                CircleObstacle(
                    id: player.id,
                    center: player.position,
                    radius: player.radius
                )
            )
        }
        obstacles.sort { $0.id < $1.id }
        return SweptCircleSolver.solve(
            start: entity.position,
            displacement: displacement,
            radius: entity.radius,
            bounds: bounds,
            obstacles: obstacles
        )
    }
    private mutating func beginEnemyAttacks() {
        for enemy in enemies where enemy.hitPoints > 0
            && !attacks.contains(where: { $0.sourceID == enemy.id })
        {
            if enemy.position.distance(to: player.position)
                <= balance.sweepTriggerDistance
            {
                let facing = (player.position - enemy.position).normalized
                if let index = enemies.firstIndex(where: { $0.id == enemy.id }) {
                    enemies[index].facing = facing
                    enemies[index].velocity = .zero
                }
                attacks.append(
                    .init(
                        sourceID: enemy.id,
                        facing: facing,
                        // Settled once, from the attack's identity rather
                        // than an RNG, so a run replays identically.
                        isReversed: SweepGeometry.isReversed(
                            sourceID: enemy.id,
                            activationTick: Int((elapsed * 60).rounded())
                        ),
                        age: 0,
                        playerTravelDistance: 0,
                        hitIDs: []
                    )
                )
            }
        }
    }
    private mutating func advanceAttacks(duration: Double, events: inout [GameEvent]) {
        for i in attacks.indices {
            let previousAge = attacks[i].age
            attacks[i].age += duration
            guard
                attacks[i].age >= balance.sweepTelegraphDuration,
                previousAge <= balance.sweepTelegraphDuration
                    + balance.sweepActiveDuration,
                let source = enemies.first(where: {
                    $0.id == attacks[i].sourceID && $0.hitPoints > 0
                })
            else {
                continue
            }

            let targetIDs = ArenaAttackResolver.eligibleTargetIDs(
                for: attacks[i],
                source: source,
                targets: [player] + enemies,
                fromAge: previousAge,
                balance: balance
            )
            for targetID in targetIDs {
                attacks[i].hitIDs.insert(targetID)
                applyDamage(
                    targetID: targetID,
                    sourceID: source.id,
                    events: &events
                )
            }
        }
        for attack in attacks
            where attack.isFinished(balance: balance)
                && !attack.hitIDs.contains(player.id)
                && attack.playerTravelDistance > 0
        {
            evadedTelegraph = true
        }
        attacks.removeAll { attack in
            attack.isFinished(balance: balance)
                || !enemies.contains(where: {
                    $0.id == attack.sourceID && $0.hitPoints > 0
                })
        }
        let dead = enemies.filter { $0.hitPoints <= 0 }; kills += dead.count; friendlyFireKills += dead.count; for e in dead { events.append(.enemyDefeated(e.id)) }; enemies.removeAll { $0.hitPoints <= 0 }
    }
    private mutating func applyDamage(
        targetID: Int,
        sourceID: Int,
        events: inout [GameEvent]
    ) {
        let position: Vector2
        if targetID == player.id {
            position = player.position
            player.hitPoints -= balance.sweepDamage
        } else if let i = enemies.firstIndex(where: { $0.id == targetID }) {
            position = enemies[i].position
            enemies[i].hitPoints -= balance.sweepDamage
        } else {
            return
        }
        events.append(
            .damaged(
                target: targetID,
                source: sourceID,
                amount: balance.sweepDamage,
                position: position
            )
        )
    }
    mutating func recordMovementTokensSpent(_ count: Int64) {
        tokensSpent += max(0, count)
        if let result {
            self.result = ArenaRunResult(
                survived: result.survived,
                elapsed: result.elapsed,
                enemiesDefeated: result.enemiesDefeated,
                friendlyFireDefeats: result.friendlyFireDefeats,
                tokensSpent: tokensSpent
            )
        }
    }
    private mutating func updateTutorial(events: inout [GameEvent]) {
        switch tutorialStage {
        case .moveAndEvade where movedDistance > 0 && evadedTelegraph:
            tutorialStage = .friendlyFire
            if let spawnedID = spawnEnemy() {
                events += [
                    .tutorialAdvanced(.friendlyFire),
                    .spawned(spawnedID),
                ]
            } else {
                events.append(.tutorialAdvanced(.friendlyFire))
            }
        case .friendlyFire
            where ArenaTutorialPolicy.shouldCompleteFriendlyFireStage(
                playerHitPoints: player.hitPoints,
                playerID: player.id,
                events: events
            ):
            tutorialStage = .endless
            spawnScheduler.reset()
            events += [.tutorialAdvanced(.endless), .tutorialCompleted]
        default:
            break
        }
    }
}
