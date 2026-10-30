import SwiftUI

struct ContactsView: View {
    @Bindable var model: ContactsModel
    @State private var path: [String] = []
    @State private var showSettings = false
    @State private var settingsError = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch model.state {
                case .permission:
                    stateView("permission.title", message: "permission.message", icon: "person.crop.circle.badge.checkmark") {
                        accessButton
                    }
                case .denied:
                    stateView("denied.title", message: "denied.message", icon: "person.crop.circle.badge.xmark") {
                        accessButton
                    }
                case .restricted:
                    stateView("restricted.title", message: "restricted.message", icon: "lock.shield") {
                        accessButton
                    }
                case .loading:
                    ProgressView("loading").frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("loading")
                case .failed:
                    stateView("error.title", message: "error.message", icon: "exclamationmark.triangle") {
                        Button("retry") { Task { await model.retryLoading() } }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("retry")
                    }
                case .loaded:
                    contactsList
                }
            }
            .navigationTitle("contacts.title")
            .navigationDestination(for: String.self) { id in
                if let contact = model.contact(id: id) { ContactDetailsView(contact: contact) }
                else { ContentUnavailableView("contact.unavailable", systemImage: "person.crop.circle.badge.xmark") }
            }
            .toolbar {
                if model.state == .loaded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("sort.title", selection: $model.sort) {
                                Text("sort.ascending").tag(ContactSort.ascending)
                                Text("sort.descending").tag(ContactSort.descending)
                            }
                        } label: { Image(systemName: "arrow.up.arrow.down") }
                        .accessibilityLabel(Text("sort.title"))
                        .accessibilityIdentifier("sort")
                    }
                }
            }
        }
        .tint(.indigo)
        .onChange(of: model.authorization) { _, value in
            if !value.canRead { path = [] }
        }
        .alert("settings.title", isPresented: $showSettings) {
            Button("settings.open") { openSettings() }
            Button("cancel", role: .cancel) {}
        } message: { Text("settings.message") }
        .alert("settings.error.title", isPresented: $settingsError) {
            Button("ok", role: .cancel) {}
        } message: { Text("settings.error.message") }
    }

    private var accessButton: some View {
        Button {
            Task { showSettings = await model.requestAccess() }
        } label: {
            Text(model.requestingAccess ? LocalizedStringKey("permission.requesting") : LocalizedStringKey("permission.request"))
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.requestingAccess)
        .accessibilityIdentifier("requestAccess")
    }

    private var contactsList: some View {
        List {
            Section {
                if model.authorization == .limited {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("limited.title", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.weight(.semibold))
                        Text("limited.message").font(.caption).foregroundStyle(.secondary)
                        Button("settings.open") { openSettings() }
                    }
                    .padding(.vertical, 4)
                }
                if model.visibleContacts.isEmpty {
                    ContentUnavailableView(
                        model.contacts.isEmpty ? LocalizedStringKey("empty.title") : LocalizedStringKey("search.empty.title"),
                        systemImage: model.contacts.isEmpty ? "person.crop.rectangle.stack" : "magnifyingglass",
                        description: Text(model.contacts.isEmpty ? LocalizedStringKey("empty.message") : LocalizedStringKey("search.empty.message"))
                    )
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("emptyState")
                } else {
                    ForEach(model.visibleContacts) { contact in
                        NavigationLink(value: contact.id) {
                            ContactRow(contact: contact)
                        }
                        .accessibilityIdentifier("contact_\(contact.id)")
                    }
                }
            } header: {
                HStack {
                    Text(String(format: String(localized: "contacts.count"), model.visibleContacts.count))
                        .accessibilityIdentifier("count")
                    Spacer()
                    Text(model.sort == .ascending ? LocalizedStringKey("sort.short.ascending") : LocalizedStringKey("sort.short.descending"))
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $model.query, prompt: "search.prompt")
        .overlay(alignment: .bottom) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                Text("\(UITestContactsRepository.fetchCount)")
                    .font(.caption2).accessibilityIdentifier("fetchCount")
                    .allowsHitTesting(false)
            }
            #endif
        }
    }

    private func stateView<Actions: View>(_ title: LocalizedStringKey, message: LocalizedStringKey,
                                          icon: String, @ViewBuilder actions: () -> Actions) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            actions()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        model.willOpenSettings()
        openURL(url) { success in settingsError = !success }
    }
}

private struct ContactRow: View {
    let contact: ContactRecord

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(contact: contact, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName.isEmpty ? String(localized: "contact.unnamed") : contact.displayName)
                    .font(.body.weight(.medium)).lineLimit(2)
                if let phone = contact.phones.first {
                    Text(phone.value).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("phone.missing").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if !contact.emails.isEmpty {
                Image(systemName: "envelope.fill").font(.footnote).foregroundStyle(.indigo)
                    .accessibilityLabel(Text("email.available"))
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

struct ContactAvatar: View {
    let contact: ContactRecord
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.indigo.opacity(0.1))
            if contact.initials.isEmpty {
                Image(systemName: "person.fill").foregroundStyle(.indigo)
            } else {
                Text(contact.initials).font(.system(size: size * 0.33, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
