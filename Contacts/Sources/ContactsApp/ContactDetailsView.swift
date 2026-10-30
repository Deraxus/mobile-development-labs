import SwiftUI

struct ContactDetailsView: View {
    let contact: ContactRecord

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ContactAvatar(contact: contact, size: 84)
                    Text(contact.displayName.isEmpty ? String(localized: "contact.unnamed") : contact.displayName)
                        .font(.title2.bold()).multilineTextAlignment(.center)
                        .accessibilityIdentifier("detailName")
                    if !contact.jobTitle.isEmpty || !contact.organization.isEmpty {
                        Text([contact.jobTitle, contact.organization].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            values("phones.title", values: contact.phones, empty: "phone.missing")
            values("emails.title", values: contact.emails, empty: "email.missing")
            if !contact.nickname.isEmpty || !contact.organization.isEmpty || !contact.department.isEmpty || !contact.jobTitle.isEmpty || !contact.birthday.isEmpty {
                Section("about.title") {
                    field("nickname.title", value: contact.nickname)
                    field("organization.title", value: contact.organization)
                    field("department.title", value: contact.department)
                    field("job.title", value: contact.jobTitle)
                    field("birthday.title", value: contact.birthday)
                }
            }
            if !contact.addresses.isEmpty { values("addresses.title", values: contact.addresses) }
            if !contact.urls.isEmpty { values("urls.title", values: contact.urls) }
            if !contact.dates.isEmpty { values("dates.title", values: contact.dates) }
            if !contact.relations.isEmpty { values("relations.title", values: contact.relations) }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("details.title")
        .navigationBarTitleDisplayMode(.inline)
        .textSelection(.enabled)
    }

    private func values(_ title: LocalizedStringKey, values: [ContactValue], empty: LocalizedStringKey? = nil) -> some View {
        Section(title) {
            if values.isEmpty, let empty { Text(empty).foregroundStyle(.secondary) }
            ForEach(values) { item in
                VStack(alignment: .leading, spacing: 4) {
                    if !item.label.isEmpty { Text(item.label).font(.caption).foregroundStyle(.secondary) }
                    Text(item.value)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private func field(_ title: LocalizedStringKey, value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value)
            }
        }
    }
}
