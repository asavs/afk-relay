//
//  AFKRelayUITestsLaunchTests.swift
//  AFKRelayUITests
//
//  Created by 野嶋伊織 on 7/26/26.
//

import XCTest

nonisolated final class AFKRelayUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Launch coverage only: reach the first interactive surface and record a
    // screenshot for each appearance. The full gameplay walkthrough lives in
    // `AFKRelayUITests` and is not repeated here.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        XCTAssertTrue(
            app.otherElements["step-onboarding"]
                .waitForExistence(timeout: 20)
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Onboarding"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
