import XCTest

/// Covers the interactive behaviour transcribed from the design: tab switching,
/// the master toggle, per-app rules, allowed-site removal, the quick-actions
/// sheet, device drill-down, the value picker, confirmations and the toast.
final class SparkFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // Always present, regardless of what each test passes: this is what
        // Store.init() keys off to use MockSparkAgentClient instead of the
        // real network client. Without it, every UI test run would attempt
        // real network calls against whatever Spark box happens to be on the
        // network the test machine is connected to (or none at all).
        app.launchArguments = arguments + ["-uiTesting"]
        app.launch()
        return app
    }

    /// The long screens put some rows below the fold; nudge them into reach.
    /// A brief settle pause after each swipe avoids computing a tap point
    /// against a scroll view that's still decelerating. A row that's *just
    /// barely* hittable at the bottom edge can have its tap point miscomputed
    /// onto the fixed tab bar/FAB sitting on top of the scroll content, so one
    /// extra overshoot swipe gives it real clearance rather than stopping the
    /// instant `isHittable` first flips true.
    private func scroll(_ app: XCUIApplication, until element: XCUIElement, attempts: Int = 15) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
        }
        if element.isHittable {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
            if !element.isHittable {
                app.swipeDown()
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
    }

    // MARK: - Tabs

    func testTabBarSwitchesScreens() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Ads blocked today"].waitForExistence(timeout: 5))

        app.buttons["Blocking Controls"].tap()
        XCTAssertTrue(app.staticTexts["What Spark blocks"].waitForExistence(timeout: 3))

        app.buttons["Parental Controls"].tap()
        XCTAssertTrue(app.staticTexts["Tim's iPhone"].waitForExistence(timeout: 3))

        app.buttons["Menu"].tap()
        XCTAssertTrue(app.staticTexts["Spark 4.2.1"].waitForExistence(timeout: 3))

        app.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Ads blocked today"].waitForExistence(timeout: 3))
    }

    /// The inline chevron in the Home caption is a shortcut into Blocking.
    func testHomeCaptionChevronOpensBlocking() {
        let app = launch()
        app.buttons["Blocking controls"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["What Spark blocks"].waitForExistence(timeout: 3))
    }

    // MARK: - Master switch

    func testMasterToggleRelabelsHeroButtonAndBlockingCard() {
        let app = launch()

        let stop = app.staticTexts["Stop Blocking Ads"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()

        XCTAssertTrue(app.staticTexts["Start Blocking Ads"].waitForExistence(timeout: 3))

        app.buttons["Blocking Controls"].tap()
        XCTAssertTrue(app.staticTexts["Blocking is paused"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Ads and trackers are getting through"].exists)
    }

    func testBlockingOnLaunchArgumentStartsPaused() {
        let app = launch(["-blockingOn", "NO"])
        XCTAssertTrue(app.staticTexts["Start Blocking Ads"].waitForExistence(timeout: 5))
    }

    // MARK: - Blocking screen

    func testPerAppRuleTogglesStatusPill() {
        let app = launch(["-activeTab", "Blocking"])

        let safari = app.staticTexts["Safari"]
        XCTAssertTrue(safari.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Blocking").count, 3)

        safari.tap()
        XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout: 3))
    }

    func testRemovingAnAllowedSiteDropsTheRow() {
        let app = launch(["-activeTab", "Blocking"])

        let remove = app.buttons["Remove localnews.co"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        scroll(app, until: remove)
        remove.tap()

        XCTAssertFalse(app.staticTexts["localnews.co"].exists)
        XCTAssertTrue(app.staticTexts["school-portal.org"].exists)
    }

    // MARK: - Quick actions

    func testQuickActionsSheetNavigatesAndCancels() {
        let app = launch()

        let fab = app.buttons["Quick actions"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()

        XCTAssertTrue(app.staticTexts["Quick actions"].waitForExistence(timeout: 3))
        app.staticTexts["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["Block a site"].exists)

        fab.tap()
        let addDevice = app.staticTexts["Add a device"]
        XCTAssertTrue(addDevice.waitForExistence(timeout: 3))
        addDevice.tap()
        // The mock Spark Agent always reports one unclaimed device.
        XCTAssertTrue(app.staticTexts["Unknown device"].waitForExistence(timeout: 3))
    }

    // MARK: - Quick-action forms

    func testBlockASiteAddsItToTheBlockedList() {
        let app = launch()

        app.buttons["Quick actions"].tap()
        XCTAssertTrue(app.staticTexts["Block a site"].waitForExistence(timeout: 3))
        app.staticTexts["Block a site"].tap()

        let field = app.textFields["Domain"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        // A pasted URL should be reduced to the bare domain.
        field.typeText("https://www.Ads-R-Us.com/tracker")
        app.buttons["Block site"].tap()

        XCTAssertTrue(app.staticTexts["ads-r-us.com blocked"].waitForExistence(timeout: 3))

        app.buttons["Blocking Controls"].tap()
        let row = app.staticTexts["ads-r-us.com"]
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        scroll(app, until: row)
        XCTAssertTrue(row.isHittable)
    }

    func testAllowASiteAddsItToTheAllowedList() {
        let app = launch(["-activeTab", "Blocking"])

        let addRow = app.buttons["Allow a site"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 5))
        scroll(app, until: addRow)
        addRow.tap()

        let field = app.textFields["Domain"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("goodsite.org")
        app.buttons["Allow site"].tap()

        XCTAssertTrue(app.staticTexts["goodsite.org allowed"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["goodsite.org"].exists)
    }

    /// The mock Spark Agent reports exactly one unclaimed device (no name, so
    /// it shows as "Unknown device") — this exercises the real claim flow,
    /// not the old fake name+kind form.
    func testAddDeviceCreatesAWorkingDevice() {
        let app = launch(["-activeTab", "Parental"])

        let addRow = app.buttons["Add a device"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 5))
        scroll(app, until: addRow)
        addRow.tap()

        let unclaimed = app.staticTexts["Unknown device"]
        XCTAssertTrue(unclaimed.waitForExistence(timeout: 3))
        unclaimed.tap()

        XCTAssertTrue(app.staticTexts["New device added"].waitForExistence(timeout: 3))

        // The new device is real: it opens, and its rules can be edited.
        let card = app.staticTexts["New device"]
        scroll(app, until: card)
        card.tap()
        XCTAssertTrue(app.staticTexts["Daily screen time"].waitForExistence(timeout: 3))
        app.staticTexts["Daily screen time"].tap()
        app.staticTexts["2h"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["0m used"].waitForExistence(timeout: 3))
    }

    func testFormPrimaryStaysDisabledUntilRequiredFieldsAreFilled() {
        let app = launch()

        app.buttons["Quick actions"].tap()
        app.staticTexts["Block a site"].tap()
        XCTAssertTrue(app.textFields["Domain"].waitForExistence(timeout: 3))

        // Nothing typed yet — submitting must not dismiss the sheet.
        app.buttons["Block site"].tap()
        XCTAssertTrue(app.textFields["Domain"].exists)

        app.staticTexts["Cancel"].tap()
        XCTAssertFalse(app.textFields["Domain"].exists)
    }

    // MARK: - Devices

    func testDeviceDrillDownAndPickerUpdatesTheRule() {
        let app = launch(["-activeTab", "Parental"])

        let device = app.staticTexts["Tim's iPhone"]
        XCTAssertTrue(device.waitForExistence(timeout: 5))
        device.tap()

        XCTAssertTrue(app.staticTexts["Daily screen time"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1h 45m used"].exists)

        app.staticTexts["Daily screen time"].tap()
        XCTAssertTrue(app.staticTexts["30m"].waitForExistence(timeout: 3))
        app.staticTexts["1h"].firstMatch.tap()

        // Used time clamps to the new, smaller limit and reports it as reached.
        XCTAssertTrue(app.staticTexts["1h used"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Limit reached"].exists)

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Set per device"].waitForExistence(timeout: 3))
    }

    func testRemovingADeviceRequiresConfirmationAndUpdatesTheMenuCount() {
        let app = launch(["-activeTab", "Parental"])

        app.staticTexts["Tim's iPhone"].tap()
        XCTAssertTrue(app.staticTexts["Remove device"].waitForExistence(timeout: 3))
        app.staticTexts["Remove device"].tap()

        XCTAssertTrue(app.staticTexts["Remove Tim's iPhone?"].waitForExistence(timeout: 3))
        app.staticTexts["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Parental controls"].waitForExistence(timeout: 3))

        app.staticTexts["Remove device"].tap()
        app.staticTexts["Remove device"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Set per device"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Tim's iPhone"].exists)

        app.buttons["Menu"].tap()
        XCTAssertTrue(app.staticTexts["2"].waitForExistence(timeout: 3))
    }

    func testRemovingEveryDeviceShowsTheEmptyState() {
        let app = launch(["-activeTab", "Parental"])

        for name in ["Tim's iPhone", "Living room iPad", "Family MacBook"] {
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
            app.staticTexts[name].tap()
            app.staticTexts["Remove device"].tap()
            app.staticTexts["Remove device"].firstMatch.tap()
        }

        XCTAssertTrue(app.staticTexts["No devices yet"].waitForExistence(timeout: 3))
    }

    // MARK: - Menu detail screens

    func testContactSupportOpensAComposeForm() {
        let app = launch(["-activeTab", "Menu"])

        app.staticTexts["Help & support"].tap()
        XCTAssertTrue(app.staticTexts["Contact support"].waitForExistence(timeout: 3))
        app.staticTexts["Contact support"].tap()

        let subject = app.textFields["Subject"]
        XCTAssertTrue(subject.waitForExistence(timeout: 3))
        subject.tap()
        subject.typeText("Ads on my bank site")

        let message = app.textViews["Message"].exists
            ? app.textViews["Message"] : app.textFields["Message"]
        message.tap()
        message.typeText("Still seeing banners after enabling Spark.")

        app.buttons["Send message"].tap()
        XCTAssertTrue(app.staticTexts["Message sent to support"].waitForExistence(timeout: 3))
    }

    /// Help topics push a list of articles, and each article opens its own screen.
    func testHelpArticlesNestTwoLevelsDeepAndPopBack() {
        let app = launch(["-activeTab", "Menu"])

        app.staticTexts["Help & support"].tap()
        XCTAssertTrue(app.staticTexts["Getting started"].waitForExistence(timeout: 3))
        app.staticTexts["Getting started"].tap()

        XCTAssertTrue(app.staticTexts["What Spark blocks"].waitForExistence(timeout: 3))
        app.staticTexts["What Spark blocks"].tap()

        XCTAssertTrue(app.staticTexts["Help article"].waitForExistence(timeout: 3))

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["6 articles"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Answers and a way to reach us"].waitForExistence(timeout: 3))
    }

    func testBrowseAllOpensTheFullFilterListCatalogue() {
        let app = launch(["-activeTab", "Blocking"])

        let browse = app.buttons["Browse all"]
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        scroll(app, until: browse)
        browse.tap()

        XCTAssertTrue(app.staticTexts["Malware domains"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Crypto mining"].exists)
    }

    func testAccountNameEditsPropagate() {
        let app = launch(["-activeTab", "Menu"])

        app.staticTexts["Timothy K."].tap()
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 3))
        app.staticTexts["Name"].tap()

        let field = app.textFields["Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.clearAndType("Alex Rivera")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Name updated"].waitForExistence(timeout: 3))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Alex Rivera"].waitForExistence(timeout: 3))
    }

    func testSignOutConfirmationReturnsHome() {
        let app = launch(["-activeTab", "Menu"])

        app.staticTexts["Sign out"].tap()
        XCTAssertTrue(app.staticTexts["Sign out of Spark?"].waitForExistence(timeout: 3))
        app.staticTexts["Sign out"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Ads blocked today"].waitForExistence(timeout: 3))
    }

    func testPrivacyDetailToggleFlips() {
        let app = launch(["-activeTab", "Menu"])

        app.staticTexts["Privacy & data"].tap()
        XCTAssertTrue(app.staticTexts["Share anonymous usage"].waitForExistence(timeout: 3))

        let toggles = app.buttons.matching(NSPredicate(format: "value == 'Off'"))
        XCTAssertGreaterThan(toggles.count, 0)
        toggles.firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "value == 'On'")).count >= 2)
    }
}

private extension XCUIElement {
    /// Text fields prefilled from state need clearing before retyping.
    func clearAndType(_ text: String) {
        if let existing = value as? String, !existing.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        typeText(text)
    }
}
