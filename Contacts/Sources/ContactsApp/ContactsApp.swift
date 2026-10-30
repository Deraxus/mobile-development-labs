import Contacts
import SwiftUI

@main
struct ContactsApp: App {
    @State private var model: ContactsModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if let repository = UITestContactsRepository.fromArguments() {
            _model = State(initialValue: ContactsModel(repository: repository))
            return
        }
        #endif
        _model = State(initialValue: ContactsModel(repository: SystemContactsRepository()))
    }

    var body: some Scene {
        WindowGroup {
            ContactsView(model: model)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.becameActive() } }
                }
                .onReceive(NotificationCenter.default.publisher(for: .CNContactStoreDidChange)) { _ in
                    Task { await model.contactsChanged() }
                }
        }
    }
}
