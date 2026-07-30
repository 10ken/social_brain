import XCTest

final class SocialBrainLaunchTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["SOCIAL_BRAIN_RUNTIME"] = "local"
        app.launchEnvironment["SOCIAL_BRAIN_UI_TESTING"] = "YES"
        app.launchEnvironment["SOCIAL_BRAIN_USE_IN_MEMORY_STORE"] = "YES"
    }

    func testAppLaunchesInLocalConfiguration() {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
    }

    func testLocalFiveTabSmokeNavigation() {
        app.launch()
        let tabBar = app.tabBars
        XCTAssertTrue(tabBar.buttons["Home"].waitForExistence(timeout: 10))

        ["Home", "Calendar", "Capture", "Communities", "Recall"].forEach { label in
            let tab = tabBar.buttons[label]
            XCTAssertTrue(tab.exists, "Missing \(label) tab in local-only build")
            tab.tap()
        }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "local-five-tab-smoke"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
