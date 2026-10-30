import XCTest
import Contacts

@MainActor
final class ContactsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws {
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ scenario: String? = "contacts", language: String = "en") {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "ru" ? "ru_RU" : "en_US"]
        if let scenario { app.launchArguments += ["--ui-testing", scenario] }
        app.launch()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSearchSortDetailsAndRotationUseOneRead() {
        launch()
        XCTAssertTrue(app.buttons["contact_anna"].waitForExistence(timeout: 10))
        app.buttons["contact_anna"].tap()
        XCTAssertTrue(app.staticTexts["detailName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["+7 900 123-45-67"].exists)
        XCTAssertTrue(app.staticTexts["+7 495 123-45-67"].exists)
        XCTAssertTrue(app.staticTexts["anna@example.org"].exists)
        attach("contact-details")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["sort"].tap()
        app.buttons["Name: Z to A"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'contact_' ")).element(boundBy: 0).identifier, "contact_zoe")
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("anna")
        XCTAssertTrue(app.buttons["contact_anna"].exists)
        XCTAssertFalse(app.buttons["contact_boris"].exists)
        search.typeText("\n")
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = expectation(for: NSPredicate { _, _ in
            let frame = self.app.windows.firstMatch.frame
            return frame.width > frame.height
        }, evaluatedWith: app)
        wait(for: [rotated], timeout: 5)
        XCTAssertTrue(app.buttons["contact_anna"].waitForExistence(timeout: 5))
        XCTAssertEqual(search.value as? String, "anna")
        attach("search-landscape")
        XCUIDevice.shared.orientation = .portrait
        search.tap()
        search.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["Nothing found"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["fetchCount"].label, "1")
        attach("empty-search")
    }

    func testMissingPhoneAndEmail() {
        launch()
        XCTAssertTrue(app.buttons["contact_boris"].waitForExistence(timeout: 10))
        app.buttons["contact_boris"].tap()
        XCTAssertTrue(app.staticTexts["No phone number"].exists)
        XCTAssertTrue(app.staticTexts["No email address"].exists)
    }

    func testPermissionCanBeRequested() {
        launch("permission")
        XCTAssertTrue(app.buttons["requestAccess"].waitForExistence(timeout: 5))
        app.buttons["requestAccess"].tap()
        XCTAssertTrue(app.buttons["contact_anna"].waitForExistence(timeout: 5))
    }

    func testDeniedOffersSettingsAndReturns() {
        launch("denied")
        XCTAssertTrue(app.staticTexts["Access not granted"].waitForExistence(timeout: 5))
        app.buttons["requestAccess"].tap()
        XCTAssertTrue(app.alerts["Open settings?"].waitForExistence(timeout: 5))
        app.alerts.buttons["Open settings"].tap()
        app.activate()
        XCTAssertTrue(app.staticTexts["Access not granted"].waitForExistence(timeout: 5))
        attach("access-denied")
    }

    func testLoadingErrorEmptyAndRestrictedStates() {
        launch("loading")
        XCTAssertTrue(app.staticTexts["Loading contacts…"].waitForExistence(timeout: 5))
        app.terminate()
        launch("error")
        XCTAssertTrue(app.buttons["retry"].waitForExistence(timeout: 5))
        app.buttons["retry"].tap()
        XCTAssertTrue(app.staticTexts["Could not read contacts"].waitForExistence(timeout: 5))
        app.terminate()
        launch("empty")
        XCTAssertTrue(app.staticTexts["No contacts"].waitForExistence(timeout: 5))
        app.terminate()
        launch("restricted")
        XCTAssertTrue(app.staticTexts["Access is restricted"].waitForExistence(timeout: 5))
    }

    func testLimitedAccessAndRussianResources() {
        launch("limited", language: "ru")
        XCTAssertTrue(app.staticTexts["Доступ к выбранным контактам"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Контакты"].exists)
        XCTAssertTrue(app.staticTexts["Найдено: 4"].exists)
        attach("contacts-russian")
    }

    func testSystemDeniedAccess() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CONTACTS_SYSTEM_TEST"] == "denied")
        launch(nil)
        XCTAssertTrue(app.staticTexts["Access not granted"].waitForExistence(timeout: 10))
        app.buttons["requestAccess"].tap()
        XCTAssertTrue(app.alerts["Open settings?"].waitForExistence(timeout: 5))
    }

    func testSystemAddressBook() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CONTACTS_SYSTEM_TEST"] == "authorized")
        let store = CNContactStore()
        let contact = CNMutableContact()
        contact.givenName = "Lab Integration"
        contact.familyName = UUID().uuidString
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile,
                                             value: CNPhoneNumber(stringValue: "+7 900 123-45-67"))]
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "lab@example.org" as NSString)]
        contact.organizationName = "University"
        let save = CNSaveRequest()
        save.add(contact, toContainerWithIdentifier: nil)
        try store.execute(save)
        defer {
            let cleanup = CNSaveRequest()
            cleanup.delete(contact)
            try? store.execute(cleanup)
        }
        launch(nil)
        XCTAssertTrue(app.staticTexts["count"].waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText(contact.familyName)
        let row = app.buttons["contact_\(contact.identifier)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["+7 900 123-45-67"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["lab@example.org"].exists)
        attach("system-address-book")
    }
}
