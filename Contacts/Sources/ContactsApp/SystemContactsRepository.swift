import Contacts
import Foundation

@MainActor
final class SystemContactsRepository: ContactsRepository {
    func authorization() -> ContactsAuthorization {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if #available(iOS 18.0, *), status == .limited { return .limited }
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .restricted: return .restricted
        default: return .denied
        }
    }

    func requestAccess() async throws {
        _ = try await CNContactStore().requestAccess(for: .contacts)
    }

    func fetchContacts() async throws -> [ContactRecord] {
        try await Task.detached(priority: .userInitiated) {
            let keys: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactNicknameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactDepartmentNameKey as CNKeyDescriptor,
                CNContactJobTitleKey as CNKeyDescriptor,
                CNContactBirthdayKey as CNKeyDescriptor,
                CNContactPostalAddressesKey as CNKeyDescriptor,
                CNContactUrlAddressesKey as CNKeyDescriptor,
                CNContactDatesKey as CNKeyDescriptor,
                CNContactRelationsKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.unifyResults = true
            var records: [ContactRecord] = []
            try CNContactStore().enumerateContacts(with: request) { contact, _ in
                records.append(ContactRecord(
                    id: contact.identifier,
                    name: CNContactFormatter.string(from: contact, style: .fullName) ?? "",
                    nickname: contact.nickname,
                    organization: contact.organizationName,
                    department: contact.departmentName,
                    jobTitle: contact.jobTitle,
                    birthday: Self.formatDate(contact.birthday),
                    phones: contact.phoneNumbers.map {
                        ContactValue(id: $0.identifier, label: Self.label($0.label), value: $0.value.stringValue)
                    },
                    emails: contact.emailAddresses.map {
                        ContactValue(id: $0.identifier, label: Self.label($0.label), value: $0.value as String)
                    },
                    addresses: contact.postalAddresses.map {
                        ContactValue(id: $0.identifier, label: Self.label($0.label),
                                     value: CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress))
                    },
                    urls: contact.urlAddresses.map {
                        ContactValue(id: $0.identifier, label: Self.label($0.label), value: $0.value as String)
                    },
                    dates: contact.dates.map {
                        ContactValue(id: $0.identifier, label: Self.label($0.label),
                                     value: Self.formatDate($0.value as DateComponents))
                    },
                    relations: contact.contactRelations.map {
                        ContactValue(id: $0.identifier, label: Self.label($0.label), value: $0.value.name)
                    }
                ))
            }
            return records
        }.value
    }

    nonisolated private static func label(_ value: String?) -> String {
        value.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? ""
    }

    nonisolated private static func formatDate(_ components: DateComponents?) -> String {
        guard var components else { return "" }
        let hasYear = components.year != nil
        if !hasYear { components.year = 2000 }
        let calendar = components.calendar ?? Calendar.current
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(hasYear ? "dMMMMyyyy" : "dMMMM")
        return formatter.string(from: date)
    }
}
