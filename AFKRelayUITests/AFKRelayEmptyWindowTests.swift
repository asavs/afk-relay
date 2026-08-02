import XCTest

/// Device-only: connecting before the day's first steps.
///
/// The eligibility window opens at midnight, so a player who connects in the
/// morning before walking has an empty window while their Health store holds
/// thirty days of history. HealthKit reports emptiness and denial the same
/// way and will not say which, and the app used to read that as "your step
/// data cannot be read" — blocking onboarding and blaming a permission that
/// was never the problem.
///
/// This launches with the window pinned to the moment of connection, which
/// makes it empty however much has been walked today. Everything else is
/// real: the reader, the Health store, the reconciliation.
///
/// It requires a device whose Health store actually has step history. On an
/// empty simulator store there is nothing to distinguish emptiness from
/// denial, and refusing to connect is the correct answer there — so this
/// suite is skipped in the simulator plan rather than asserted loosely.
nonisolated final class AFKRelayEmptyWindowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyEligibilityWindowStillConnects() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-empty-window"]
        app.launch()

        let onboarding = app.descendants(matching: .any)["step-onboarding"]
        XCTAssertTrue(onboarding.waitForExistence(timeout: 20))

        let connect = app.buttons["connect-steps"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()

        let home = app.descendants(matching: .any)["game-home"]
        if !handleHealthAccessSheetIfPresented(in: app),
           !home.exists,
           connect.exists
        {
            connect.tap()
            _ = handleHealthAccessSheetIfPresented(in: app)
        }

        XCTAssertTrue(
            home.waitForExistence(timeout: 30),
            """
            An empty eligibility window must connect with a zero credit. \
            Staying in onboarding means the app is still reading "nothing \
            since midnight" as "cannot read Health".
            """
        )

        // Zero steps and connected is the whole point: the bank exists and
        // reads empty, rather than the run being unreachable.
        let bank = app.descendants(matching: .any)["movement-bank"]
        XCTAssertTrue(bank.waitForExistence(timeout: 10))
        if let value = bank.value as? String {
            XCTAssertTrue(
                value.hasPrefix("0 "),
                "A window opened at connection can credit nothing: \(value)"
            )
        }

        // Nothing is earned yet, so the run must be honestly unavailable
        // rather than the app pretending the bank is spendable.
        XCTAssertFalse(
            app.buttons["start-run"].isEnabled,
            "A zero bank cannot start a run"
        )
    }

    /// iOS presents the Health access sheet only for an app it has no
    /// decision for. A device that already decided proceeds straight through.
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
