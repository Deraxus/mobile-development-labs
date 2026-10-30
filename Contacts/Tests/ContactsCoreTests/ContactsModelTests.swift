import XCTest
@testable import ContactsCore

@MainActor
private final class TestRepository: ContactsRepository {
    var status: ContactsAuthorization = .authorized
    var requestedStatus: ContactsAuthorization = .authorized
    var fetchCount = 0
    var requestCount = 0
    var shouldFail = false
    var delay = false
    var continuation: CheckedContinuation<[ContactRecord], any Error>?
    var records = [
        ContactRecord(id: "3", name: "Zoé"),
        ContactRecord(id: "1", name: "Anna"),
        ContactRecord(id: "2", name: "Boris")
    ]

    func authorization() -> ContactsAuthorization { status }
    func requestAccess() async throws { requestCount += 1; status = requestedStatus }
    func fetchContacts() async throws -> [ContactRecord] {
        fetchCount += 1
        if shouldFail { throw CocoaError(.fileReadUnknown) }
        if delay { return try await withCheckedThrowingContinuation { continuation = $0 } }
        return records
    }
}

final class ContactsModelTests: XCTestCase {
    @MainActor func testSearchAndBothSortsUseCachedContacts() async {
        let repository = TestRepository()
        let model = ContactsModel(repository: repository)
        await model.start()
        XCTAssertEqual(model.visibleContacts.map(\.name), ["Anna", "Boris", "Zoé"])
        model.query = " zOE "
        XCTAssertEqual(model.visibleContacts.map(\.name), ["Zoé"])
        model.query = "missing"
        XCTAssertTrue(model.visibleContacts.isEmpty)
        model.query = ""
        model.sort = .descending
        XCTAssertEqual(model.visibleContacts.map(\.name), ["Zoé", "Boris", "Anna"])
        XCTAssertEqual(repository.fetchCount, 1)
    }

    @MainActor func testStartForegroundAndDetailsDoNotReload() async {
        let repository = TestRepository()
        let model = ContactsModel(repository: repository)
        await model.start()
        await model.start()
        await model.becameActive()
        XCTAssertNotNil(model.contact(id: "1"))
        await model.becameActive()
        XCTAssertEqual(repository.fetchCount, 1)
    }

    @MainActor func testDenialIsDifferentFromEmptyAddressBook() async {
        let repository = TestRepository()
        repository.status = .denied
        let model = ContactsModel(repository: repository)
        await model.start()
        XCTAssertEqual(model.state, .denied)
        XCTAssertEqual(repository.fetchCount, 0)
        let settings = await model.requestAccess()
        XCTAssertTrue(settings)
        XCTAssertEqual(repository.requestCount, 0)
        repository.status = .authorized
        repository.records = []
        await model.becameActive()
        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(model.contacts.isEmpty)
    }

    @MainActor func testPermissionRequestGrantAndDenial() async {
        for result in [ContactsAuthorization.authorized, .limited, .denied] {
            let repository = TestRepository()
            repository.status = .notDetermined
            repository.requestedStatus = result
            let model = ContactsModel(repository: repository)
            await model.start()
            XCTAssertEqual(model.state, .permission)
            let settings = await model.requestAccess()
            XCTAssertFalse(settings)
            XCTAssertEqual(repository.requestCount, 1)
            XCTAssertEqual(model.authorization, result)
            XCTAssertEqual(model.state, result.canRead ? .loaded : .denied)
            XCTAssertEqual(repository.fetchCount, result.canRead ? 1 : 0)
        }
    }

    @MainActor func testRestrictedDoesNotReadOrRepeatSystemPrompt() async {
        let repository = TestRepository()
        repository.status = .restricted
        let model = ContactsModel(repository: repository)
        await model.start()
        let settings = await model.requestAccess()
        XCTAssertTrue(settings)
        XCTAssertEqual(model.state, .restricted)
        XCTAssertEqual(repository.fetchCount, 0)
        XCTAssertEqual(repository.requestCount, 0)
    }

    @MainActor func testRevokedPermissionClearsCachedPrivateData() async {
        let repository = TestRepository()
        let model = ContactsModel(repository: repository)
        await model.start()
        repository.status = .denied
        await model.becameActive()
        XCTAssertEqual(model.state, .denied)
        XCTAssertTrue(model.contacts.isEmpty)
        XCTAssertTrue(model.visibleContacts.isEmpty)
        XCTAssertNil(model.contact(id: "1"))
        repository.status = .authorized
        await model.becameActive()
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(repository.fetchCount, 2)
    }

    @MainActor func testSettingsReturnReloadsLimitedSelectionAndPreservesSearch() async {
        let repository = TestRepository()
        repository.status = .limited
        let model = ContactsModel(repository: repository)
        await model.start()
        model.query = "Ann"
        model.sort = .descending
        model.willOpenSettings()
        repository.records = [ContactRecord(id: "4", name: "Annette")]
        await model.becameActive()
        XCTAssertEqual(model.visibleContacts.map(\.name), ["Annette"])
        XCTAssertEqual(model.query, "Ann")
        XCTAssertEqual(model.sort, .descending)
        XCTAssertEqual(repository.fetchCount, 2)
    }

    @MainActor func testReadErrorAndRetry() async {
        let repository = TestRepository()
        repository.shouldFail = true
        let model = ContactsModel(repository: repository)
        await model.start()
        XCTAssertEqual(model.state, .failed)
        repository.shouldFail = false
        await model.retryLoading()
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.contacts.count, 3)
    }

    @MainActor func testExternalChangesRefreshOnlyWhenNotified() async {
        let repository = TestRepository()
        let model = ContactsModel(repository: repository)
        await model.start()
        repository.records = []
        await model.contactsChanged()
        XCTAssertTrue(model.contacts.isEmpty)
        XCTAssertEqual(repository.fetchCount, 2)
    }

    @MainActor func testRevocationDuringReadDiscardsLateResult() async {
        let repository = TestRepository()
        repository.delay = true
        let model = ContactsModel(repository: repository)
        let reading = Task { await model.start() }
        while repository.continuation == nil { await Task.yield() }
        XCTAssertEqual(model.state, .loading)
        repository.status = .denied
        await model.becameActive()
        repository.continuation?.resume(returning: repository.records)
        await reading.value
        XCTAssertEqual(model.state, .denied)
        XCTAssertTrue(model.contacts.isEmpty)
    }

    @MainActor func testConcurrentForegroundDoesNotDuplicateRead() async {
        let repository = TestRepository()
        repository.delay = true
        let model = ContactsModel(repository: repository)
        let reading = Task { await model.start() }
        while repository.continuation == nil { await Task.yield() }
        await model.becameActive()
        repository.continuation?.resume(returning: repository.records)
        await reading.value
        XCTAssertEqual(repository.fetchCount, 1)
    }

    @MainActor func testTenThousandContactsAndMissingFields() async {
        let repository = TestRepository()
        repository.records = (0..<10_000).map { ContactRecord(id: "\($0)", name: "Person \($0)") }
        repository.records.append(ContactRecord(id: "unnamed", name: ""))
        let model = ContactsModel(repository: repository)
        await model.start()
        XCTAssertEqual(model.contacts.count, 10_001)
        model.query = "Person 9999"
        XCTAssertEqual(model.visibleContacts.count, 1)
        XCTAssertTrue(model.visibleContacts[0].phones.isEmpty)
        XCTAssertTrue(model.visibleContacts[0].emails.isEmpty)
        XCTAssertEqual(repository.fetchCount, 1)
    }
}
