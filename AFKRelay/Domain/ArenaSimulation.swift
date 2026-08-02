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
/// What kind of enemy a body is, and therefore how it moves and what it
/// throws. A silhouette is a promise about behaviour, so the two archetypes
/// never share one (`ADR-0020`).
nonisolated enum EnemyArchetype: String, Codable, Equatable, Sendable {
    /// Closes to melee range and sweeps an arc.
    case chevron
    /// Holds a standoff distance and fires down a lane.
    case marksman
}
nonisolated struct ArenaEntity: Equatable, Sendable {
    let id: Int
    var position: Vector2
    var velocity: Vector2
    var facing: Vector2
    var radius: Double
    var hitPoints: Int
    var isPlayer: Bool
    var archetype: EnemyArchetype = .chevron
}
nonisolated struct ArenaAttack: Equatable, Sendable {
    /// Which geometry this attack is. The catalogue of primitives grows here
    /// rather than by branching enemies into their own attack arrays.
    enum Kind: String, Equatable, Sendable {
        case sweep
        case shot
    }

    let sourceID: Int
    let facing: Vector2
    var kind: Kind = .sweep
    /// Where a shot left the muzzle. Fixed at fire time, because a shot in
    /// flight belongs to the world rather than to the body that fired it —
    /// it keeps travelling if its shooter moves, and if its shooter dies.
    /// Sweeps ignore this and read their origin from the pose-locked source.
    var origin: Vector2 = .zero
    /// Whether this blade crosses its arc backwards. Fixed for the life of
    /// the attack and settled when it is thrown, so the direction a player
    /// reads during the telegraph is the direction that lands.
    var isReversed = false
    var age: Double
    var playerTravelDistance: Double
    var hitIDs: Set<Int>
    /// How far along its axis a shot was stopped, once something stopped it.
    /// `nil` while the lane ahead is still clear.
    var stopDistance: Double?

    func isActive(balance: MVPBalance = .v3) -> Bool {
        switch kind {
        case .sweep:
            if case .active = SweepGeometry.phase(at: age, balance: balance) {
                return true
            }
            return false
        case .shot:
            if case .flight = ShotGeometry.phase(
                at: age,
                stoppedAt: stopDistance,
                balance: balance
            ) {
                return true
            }
            return false
        }
    }

    func isFinished(balance: MVPBalance = .v3) -> Bool {
        switch kind {
        case .sweep:
            SweepGeometry.phase(at: age, balance: balance) == .finished
        case .shot:
            ShotGeometry.phase(
                at: age,
                stoppedAt: stopDistance,
                balance: balance
            ) == .finished
        }
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
    private var spawnScheduler = EndlessSpawnScheduler(); private var nextID = 1; private var endlessSpawnCount = 0; private var kills = 0; private var friendlyFireKills = 0; private var movedDistance = 0.0; private var evadedTelegraph = false; private(set) var tokensSpent: Int64 = 0; private(set) var lastPlayerTravelDistance = 0.0; private(set) var lastPlayerCollisionNormals: [Vector2] = []
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
    /// Which archetype the next spawn takes.
    ///
    /// Counted rather than sampled, like every other choice the simulation
    /// makes, so a run replays identically. Staging only ever fields chevrons:
    /// the first-run sequence teaches the sweep, and a shooter arriving
    /// mid-lesson would teach something else at the same time.
    private func nextArchetype() -> EnemyArchetype {
        guard tutorialStage == .endless, balance.marksmanSpawnPeriod > 0 else {
            return .chevron
        }
        let livingMarksmen = enemies.count { $0.archetype == .marksman }
        guard livingMarksmen < balance.marksmanCap else { return .chevron }
        return endlessSpawnCount % balance.marksmanSpawnPeriod
            == balance.marksmanSpawnPeriod - 1 ? .marksman : .chevron
    }

    @discardableResult
    private mutating func spawnEnemy() -> Int? {
        let archetype = nextArchetype()
        let radius = archetype == .marksman
            ? balance.marksmanRadius
            : balance.enemyRadius
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
                hitPoints: archetype == .marksman
                    ? balance.marksmanHitPoints
                    : balance.enemyHitPoints,
                isPlayer: false,
                archetype: archetype
            )
        )
        nextID += 1
        if tutorialStage == .endless {
            endlessSpawnCount += 1
        }
        return id
    }
    private mutating func moveEnemies(duration: Double) {
        for i in enemies.indices {
            let toward = (player.position - enemies[i].position).normalized
            // A body that is winding up stops and holds the pose it will
            // strike from. The sweep holds through its active phase because
            // the blade is attached to it; the shot only holds while aiming,
            // since once the bolt is away it belongs to the world.
            let poseIsLocked = attacks.contains { attack in
                guard attack.sourceID == enemies[i].id else { return false }
                switch attack.kind {
                case .sweep:
                    switch SweepGeometry.phase(at: attack.age, balance: balance) {
                    case .telegraph, .active:
                        return true
                    case .recovery, .finished:
                        return false
                    }
                case .shot:
                    switch ShotGeometry.phase(
                        at: attack.age,
                        stoppedAt: attack.stopDistance,
                        balance: balance
                    ) {
                    case .telegraph:
                        return true
                    case .flight, .recovery, .finished:
                        return false
                    }
                }
            }
            guard !poseIsLocked else {
                enemies[i].velocity = .zero
                continue
            }

            enemies[i].velocity = desiredVelocity(for: enemies[i], toward: toward)
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

    /// Where an enemy wants to be next tick.
    ///
    /// The chevron wants to be on top of the player. The marksman wants to be
    /// exactly `shotStandoffDistance` away — it closes when it is too far,
    /// backs off when the player crowds it, and circles inside the band
    /// between. Circling is what stops a group of shooters from converging on
    /// one point and firing down the same lane.
    private func desiredVelocity(
        for enemy: ArenaEntity,
        toward: Vector2
    ) -> Vector2 {
        switch enemy.archetype {
        case .chevron:
            let speed = tutorialStage == .endless
                ? balance.enemySpeed
                : balance.tutorialEnemySpeed
            return toward * speed
        case .marksman:
            let distance = enemy.position.distance(to: player.position)
            let band = balance.shotStandoffBand
            if distance > balance.shotStandoffDistance + band {
                return toward * balance.marksmanSpeed
            }
            if distance < balance.shotStandoffDistance - band {
                return toward * -balance.marksmanSpeed
            }
            // Which way it circles comes from the body's identifier, not a
            // draw, so the arena stays replayable.
            let sign: Double = enemy.id.isMultiple(of: 2) ? 1 : -1
            let orbit = Vector2(x: -toward.y, y: toward.x) * sign
            return orbit * (balance.marksmanSpeed * 0.8)
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
            let distance = enemy.position.distance(to: player.position)
            let trigger = enemy.archetype == .marksman
                ? balance.shotTriggerDistance
                : balance.sweepTriggerDistance
            guard distance <= trigger else { continue }

            let facing = (player.position - enemy.position).normalized
            if let index = enemies.firstIndex(where: { $0.id == enemy.id }) {
                enemies[index].facing = facing
                enemies[index].velocity = .zero
            }

            switch enemy.archetype {
            case .chevron:
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
            case .marksman:
                // The lane is aimed where the player stands when the warning
                // appears and never corrects. A telegraph that tracks is not
                // a telegraph — the whole cost of the shot is the moment it
                // gives the player to leave.
                //
                // Nor does firing check whether anything already blocks the
                // lane. Aim is naive and the world resolves it: a shot loosed
                // at a player standing behind a chevron kills the chevron.
                attacks.append(
                    .init(
                        sourceID: enemy.id,
                        facing: facing,
                        kind: .shot,
                        origin: enemy.position,
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
            switch attacks[i].kind {
            case .sweep:
                advanceSweep(at: i, previousAge: previousAge, events: &events)
            case .shot:
                advanceShot(at: i, previousAge: previousAge, events: &events)
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
            if attack.isFinished(balance: balance) { return true }
            // A sweep is the body's own limb, so it dies with the body. A
            // shot has already left, and a bolt in flight does not blink out
            // because whoever fired it was killed on the way.
            return attack.kind == .sweep
                && !enemies.contains(where: {
                    $0.id == attack.sourceID && $0.hitPoints > 0
                })
        }
        let dead = enemies.filter { $0.hitPoints <= 0 }; kills += dead.count; friendlyFireKills += dead.count; for e in dead { events.append(.enemyDefeated(e.id)) }; enemies.removeAll { $0.hitPoints <= 0 }
    }
    private mutating func advanceSweep(
        at index: Int,
        previousAge: Double,
        events: inout [GameEvent]
    ) {
        guard
            attacks[index].age >= balance.sweepTelegraphDuration,
            previousAge <= balance.sweepTelegraphDuration
                + balance.sweepActiveDuration,
            let source = enemies.first(where: {
                $0.id == attacks[index].sourceID && $0.hitPoints > 0
            })
        else {
            return
        }

        let targetIDs = ArenaAttackResolver.eligibleTargetIDs(
            for: attacks[index],
            source: source,
            targets: [player] + enemies,
            fromAge: previousAge,
            balance: balance
        )
        for targetID in targetIDs {
            attacks[index].hitIDs.insert(targetID)
            applyDamage(
                targetID: targetID,
                sourceID: source.id,
                amount: balance.sweepDamage,
                events: &events
            )
        }
    }

    /// Advances a shot's nose across this tick and resolves what it ran into.
    ///
    /// A shot stops at the first body it meets rather than piercing
    /// (`ADR-0020`): standing behind something is only cover if the thing in
    /// front actually takes the hit. One stop means one hit, so a shot damages
    /// at most one target in its life.
    private mutating func advanceShot(
        at index: Int,
        previousAge: Double,
        events: inout [GameEvent]
    ) {
        guard
            attacks[index].stopDistance == nil,
            attacks[index].age > balance.shotTelegraphDuration
        else {
            return
        }

        let fromDistance = ShotGeometry.noseDistance(
            at: previousAge,
            balance: balance
        )
        let throughDistance = ShotGeometry.noseDistance(
            at: attacks[index].age,
            balance: balance
        )

        if let block = ShotGeometry.firstBlock(
            origin: attacks[index].origin,
            axis: attacks[index].facing,
            fromDistance: fromDistance,
            throughDistance: throughDistance,
            targets: [player] + enemies,
            sourceID: attacks[index].sourceID,
            balance: balance
        ) {
            attacks[index].stopDistance = block.distance
            attacks[index].hitIDs.insert(block.targetID)
            applyDamage(
                targetID: block.targetID,
                sourceID: attacks[index].sourceID,
                amount: balance.shotDamage,
                events: &events
            )
        } else if throughDistance >= balance.shotRange {
            attacks[index].stopDistance = balance.shotRange
        }
    }

    private mutating func applyDamage(
        targetID: Int,
        sourceID: Int,
        amount: Int,
        events: inout [GameEvent]
    ) {
        let position: Vector2
        if targetID == player.id {
            position = player.position
            player.hitPoints -= amount
        } else if let i = enemies.firstIndex(where: { $0.id == targetID }) {
            position = enemies[i].position
            enemies[i].hitPoints -= amount
        } else {
            return
        }
        events.append(
            .damaged(
                target: targetID,
                source: sourceID,
                amount: amount,
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
