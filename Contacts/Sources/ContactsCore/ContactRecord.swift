import Foundation

public struct ContactValue: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String = "", value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct ContactRecord: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var nickname: String
    public var organization: String
    public var department: String
    public var jobTitle: String
    public var birthday: String
    public var phones: [ContactValue]
    public var emails: [ContactValue]
    public var addresses: [ContactValue]
    public var urls: [ContactValue]
    public var dates: [ContactValue]
    public var relations: [ContactValue]

    public init(id: String, name: String, nickname: String = "", organization: String = "",
                department: String = "", jobTitle: String = "", birthday: String = "",
                phones: [ContactValue] = [], emails: [ContactValue] = [],
                addresses: [ContactValue] = [], urls: [ContactValue] = [],
                dates: [ContactValue] = [], relations: [ContactValue] = []) {
        self.id = id
        self.name = name
        self.nickname = nickname
        self.organization = organization
        self.department = department
        self.jobTitle = jobTitle
        self.birthday = birthday
        self.phones = phones
        self.emails = emails
        self.addresses = addresses
        self.urls = urls
        self.dates = dates
        self.relations = relations
    }

    public var displayName: String {
        [name, organization, nickname].first { !$0.isEmpty } ?? ""
    }

    public var initials: String {
        String(displayName.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first)).uppercased()
    }
}

public enum ContactsAuthorization: Equatable, Sendable {
    case notDetermined, authorized, limited, denied, restricted
    public var canRead: Bool { self == .authorized || self == .limited }
}

public enum ContactsScreenState: Equatable {
    case permission, denied, restricted, loading, loaded, failed
}

public enum ContactSort: String, CaseIterable, Sendable {
    case ascending, descending
}

@MainActor
public protocol ContactsRepository: AnyObject {
    func authorization() -> ContactsAuthorization
    func requestAccess() async throws
    func fetchContacts() async throws -> [ContactRecord]
}
