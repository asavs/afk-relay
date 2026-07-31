//
//  AFKRelayUITests.swift
//  AFKRelayUITests
//
//  Created by 野嶋伊織 on 7/26/26.
//

import XCTest

nonisolated final class AFKRelayUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGameplayProofFlow() throws {
        let app = launchDeterministicApp()

        XCTAssertTrue(
            app.descendants(matching: .any)["step-onboarding"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["connect-steps"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["game-home"]
                .waitForExistence(timeout: 5)
        )
        let bank = app.descendants(matching: .any)["movement-bank"]
        XCTAssertTrue(bank.waitForExistence(timeout: 2))
        XCTAssertEqual(bank.value as? String, "12,000 tokens available")

        app.buttons["start-run"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["arena-hud"]
                .waitForExistence(timeout: 5)
        )
        let joystick = app.descendants(matching: .any)["movement-joystick"]
        XCTAssertTrue(joystick.waitForExistence(timeout: 2))
        joystick.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        ).press(forDuration: 0.7)

        app.buttons["pause-run"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["run-paused"]
                .waitForExistence(timeout: 2)
        )
        app.buttons["Settings"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["game-settings"]
                .waitForExistence(timeout: 2)
        )
        app.buttons["end-run"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["run-summary"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Run Complete"].exists)
        XCTAssertTrue(app.staticTexts["Records only"].exists)
        app.buttons["return-home"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["game-home"]
                .waitForExistence(timeout: 2)
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing"]
            app.launch()
        }
    }

    @MainActor
    private func launchDeterministicApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }
}
