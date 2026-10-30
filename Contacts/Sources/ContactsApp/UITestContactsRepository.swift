#if DEBUG
import Foundation

@MainActor
final class UITestContactsRepository: ContactsRepository {
    static var fetchCount = 0
    private let scenario: String
    private var access: ContactsAuthorization

    init(scenario: String) {
        self.scenario = scenario
        access = scenario == "permission" ? .notDetermined : scenario == "denied" ? .denied :
            scenario == "restricted" ? .restricted : scenario == "limited" ? .limited : .authorized
        Self.fetchCount = 0
    }

    static func fromArguments() -> UITestContactsRepository? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--ui-testing"), arguments.indices.contains(index + 1) else { return nil }
        return UITestContactsRepository(scenario: arguments[index + 1])
    }

    func authorization() -> ContactsAuthorization { access }
    func requestAccess() async throws { access = .authorized }

    func fetchContacts() async throws -> [ContactRecord] {
        Self.fetchCount += 1
        if scenario == "loading" { try await Task.sleep(for: .seconds(15)) }
        if scenario == "error" { throw CocoaError(.fileReadUnknown) }
        if scenario == "empty" { return [] }
        return [
            ContactRecord(id: "anna", name: "Anna Volkova", organization: "University",
                          jobTitle: "Lecturer", birthday: "15 May",
                          phones: [ContactValue(id: "p1", label: "mobile", value: "+7 900 123-45-67"),
                                   ContactValue(id: "p2", label: "work", value: "+7 495 123-45-67")],
                          emails: [ContactValue(id: "e1", label: "work", value: "anna@example.org")],
                          addresses: [ContactValue(id: "a1", label: "work", value: "University Street, 1")]),
            ContactRecord(id: "boris", name: "Boris Smirnov"),
            ContactRecord(id: "zoe", name: "Zoé Martin",
                          emails: [ContactValue(id: "e2", value: "zoe@example.org")]),
            ContactRecord(id: "unnamed", name: "")
        ]
    }
}
#endif
