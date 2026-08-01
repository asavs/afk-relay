//
//  AFKRelayUITests.swift
//  AFKRelayUITests
//
//  Created by 野嶋伊織 on 7/26/26.
//

import XCTest

/// Three ordered scenarios, one launch each:
///
/// 1. A hermetic gameplay proof: seeded 1,000-step bank, the full loop from
///    onboarding through movement, pause, death, and records.
/// 2. Live HealthKit onboarding from scratch against disposable storage; the
///    real permission sheet is handled when iOS presents it.
/// 3. An instrumented performance pass over a saturated arena with every
///    diagnostics layer enabled.
///
/// Launch-screenshot and launch-time tests live in
/// `AFKRelayUITestsLaunchTests` and run from the simulator test plan only.
nonisolated final class AFKRelayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Scenario 1: seeded bank, full gameplay loop until death

    @MainActor
    func testGameplayLoopWithSeededBank() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-steps=1000"]
        app.launch()

        // Onboarding mints exactly the seeded steps.
        XCTAssertTrue(
            element(app, "step-onboarding").waitForExistence(timeout: 20)
        )
        tap(app, button: "connect-steps", toReveal: "game-home")
        let bank = element(app, "movement-bank")
        XCTAssertTrue(bank.waitForExistence(timeout: 5))
        XCTAssertEqual(bank.value as? String, "1,000 tokens available")

        // Movement spends from the bank. A drag delivers a continuous
        // event stream; a stationary synthesized press is a single
        // droppable touch-down.
        tap(app, button: "start-run", toReveal: "arena-hud")
        let joystick = element(app, "movement-joystick")
        XCTAssertTrue(joystick.waitForExistence(timeout: 5))
        let center = joystick.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        )
        let edge = joystick.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        )
        center.press(forDuration: 0.3, thenDragTo: edge)
        center.press(forDuration: 0.3, thenDragTo: edge)

        // Pause blocks the arena and resume returns to it.
        tap(app, button: "pause-run", toReveal: "run-paused")
        tap(app, button: "Resume", toReveal: "arena-hud")

        // Standing still, the tutorial enemy telegraphs and lands three
        // hits; the run must end in the summary with records language.
        XCTAssertTrue(
            element(app, "run-summary").waitForExistence(timeout: 120)
        )
        XCTAssertTrue(app.staticTexts["Run Over"].exists)
        XCTAssertTrue(
            app.staticTexts["Runs are recorded on this iPhone only."].exists
        )

        // The wallet survives death and reflects only real spending.
        tap(app, button: "return-home", toReveal: "game-home")
        let remaining = bank.value as? String ?? ""
        XCTAssertNotEqual(remaining, "1,000 tokens available")
        XCTAssertTrue(
            remaining.wholeMatch(of: #/[\d,]+ tokens available/#) != nil,
            "Unexpected bank value: \(remaining)"
        )
    }

    // MARK: - Scenario 2: live HealthKit onboarding from scratch

    @MainActor
    func testLiveHealthKitOnboardingFromScratch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-live-health"]
        app.launch()

        XCTAssertTrue(
            element(app, "step-onboarding").waitForExistence(timeout: 20)
        )
        let connect = app.buttons["connect-steps"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()

        // iOS presents the Health access sheet only for an undecided app.
        // Handle it when it appears; a previously decided device or
        // simulator proceeds straight to the query. Retap once if the tap
        // was swallowed by a transition and neither surface arrived.
        if !handleHealthAccessSheetIfPresented(in: app),
           !element(app, "game-home").exists,
           connect.exists
        {
            connect.tap()
            _ = handleHealthAccessSheetIfPresented(in: app)
        }

        // Two outcomes are canonical for a live store. A readable merged
        // aggregate (any size, including zero) completes onboarding into the
        // home wallet. A store with no readable samples — an empty simulator
        // Health store is indistinguishable from denied access — must land
        // in the honest no-readable-data recovery state with retry offered,
        // never a claimed denial.
        let home = element(app, "game-home")
        let recovery = app.staticTexts["No step data yet"]
        let outcome = XCTWaiter.wait(
            for: [
                XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == true"),
                    object: home
                ),
            ],
            timeout: 30
        )

        if outcome == .completed {
            let bank = element(app, "movement-bank")
            XCTAssertTrue(bank.waitForExistence(timeout: 5))
            let value = bank.value as? String ?? ""
            XCTAssertTrue(
                value.wholeMatch(of: #/[\d,]+ tokens available/#) != nil,
                "Unexpected bank value: \(value)"
            )
        } else {
            XCTAssertTrue(
                recovery.waitForExistence(timeout: 5),
                "Neither the home wallet nor the honest recovery state appeared"
            )
            XCTAssertTrue(app.buttons["connect-steps"].exists)
            XCTAssertTrue(app.buttons["Review Steps Access"].exists)
        }
    }

    // MARK: - Scenario 3: instrumented performance under swarm pressure

    @MainActor
    func testArenaPerformanceUnderPressure() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-perf-arena"]
        app.launch()

        // Seeded wallet and completed tutorial land directly on home.
        XCTAssertTrue(element(app, "game-home").waitForExistence(timeout: 20))
        tap(app, button: "start-run", toReveal: "arena-hud")
        let joystick = element(app, "movement-joystick")
        XCTAssertTrue(joystick.waitForExistence(timeout: 5))

        // Let rapid spawning reach the 20-enemy cap before measuring.
        joystick.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)
        ).press(forDuration: 12)

        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(
            metrics: [
                XCTCPUMetric(application: app),
                XCTMemoryMetric(application: app),
            ],
            options: options
        ) {
            // Sustained movement against the capped swarm with all
            // diagnostics layers rendering.
            joystick.coordinate(
                withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
            ).press(forDuration: 20)
        }

        // The diagnostics overlay reports the rendered frame rate; require
        // a sanity floor here. The canonical 60 FPS gate remains the
        // instrumented manual pass on the oldest supported device.
        let fpsLabel = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Render '")
        ).firstMatch
        XCTAssertTrue(fpsLabel.waitForExistence(timeout: 5))
        let label = fpsLabel.label
        let fps = Int(label.dropFirst("Render ".count).prefix { $0.isNumber })
        XCTAssertNotNil(fps, "Unreadable frame-rate label: \(label)")

        let attachment = XCTAttachment(string: "Measured \(label)")
        attachment.name = "Arena frame rate under pressure"
        attachment.lifetime = .keepAlways
        add(attachment)
#if !targetEnvironment(simulator)
        // The frame-rate floor is meaningful only on real hardware; the
        // simulator's software renderer reports whatever the host allows.
        // The canonical 60 FPS gate is the manual pass on the oldest
        // supported device.
        XCTAssertGreaterThanOrEqual(fps ?? 0, 30)
#endif
    }

    // MARK: - Helpers

    @MainActor
    private func element(
        _ app: XCUIApplication,
        _ identifier: String
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Taps a button and verifies the expected surface appears, retapping
    /// when a transition swallowed the synthesized event. Tap delivery
    /// during SwiftUI screen changes is not reliable enough to assert on a
    /// single attempt.
    @MainActor
    private func tap(
        _ app: XCUIApplication,
        button identifier: String,
        toReveal revealed: String
    ) {
        let button = app.buttons[identifier]
        XCTAssertTrue(
            button.waitForExistence(timeout: 20),
            "Missing button: \(identifier)"
        )
        let target = element(app, revealed)
        for _ in 0..<3 {
            button.tap()
            if target.waitForExistence(timeout: 10) {
                return
            }
        }
        XCTFail("\(revealed) did not appear after tapping \(identifier)")
    }

    /// Returns true when the sheet was seen and handled. The Health access
    /// sheet exposes stable locale-independent `UIA.Health.*` identifiers.
    @MainActor
    @discardableResult
    private func handleHealthAccessSheetIfPresented(
        in app: XCUIApplication
    ) -> Bool {
        let stepsSwitch = app.switches["UIA.Health.Steps.SwitchCell.Switch"]
        guard stepsSwitch.waitForExistence(timeout: 10) else { return false }
        if (stepsSwitch.value as? String) != "1" {
            stepsSwitch.tap()
        }

        let allow = app.buttons["UIA.Health.Allow.Button"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
        return true
    }
}
