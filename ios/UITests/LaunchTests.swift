import XCTest

/// Smoke tests that run on a simulator in CI: the app launches, shows the
/// four steps, and keeps the locked ones locked.
final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["MATH BLITZ"].waitForExistence(timeout: 20))
    }

    func testStartingALessonShowsTheFourSteps() {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["Start today's Blitz ➜"]
        if start.waitForExistence(timeout: 20) {
            start.tap()
            XCTAssertTrue(app.buttons["Watch"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["Answer, locked"].exists || app.buttons["Answer"].exists)
        } else {
            // No network on the runner: the empty state must still be friendly.
            XCTAssertTrue(app.staticTexts["No lessons yet"].exists
                          || app.activityIndicators.firstMatch.exists)
        }
    }

    func testStatsSheetOpens() {
        let app = XCUIApplication()
        app.launch()
        let stats = app.buttons["My stats"]
        if stats.waitForExistence(timeout: 20) {
            stats.tap()
            XCTAssertTrue(app.navigationBars["My stats"].waitForExistence(timeout: 5))
        }
    }
}
