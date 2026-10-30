import Foundation
import Observation

@MainActor @Observable
public final class ContactsModel {
    public private(set) var contacts: [ContactRecord] = []
    public private(set) var visibleContacts: [ContactRecord] = []
    public private(set) var authorization: ContactsAuthorization = .notDetermined
    public private(set) var state: ContactsScreenState = .permission
    public private(set) var requestingAccess = false
    public var query = "" { didSet { filterContacts() } }
    public var sort: ContactSort = .ascending { didSet { filterContacts() } }

    @ObservationIgnored private let repository: any ContactsRepository
    @ObservationIgnored private var started = false
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var refreshing = false
    @ObservationIgnored private var returnedFromSettings = false
    @ObservationIgnored private var revision = 0

    public init(repository: any ContactsRepository) { self.repository = repository }

    public func start() async {
        guard !started else { return }
        started = true
        await refresh()
    }

    public func becameActive() async {
        let force = returnedFromSettings
        returnedFromSettings = false
        await refresh(force: force)
    }

    public func willOpenSettings() { returnedFromSettings = true }

    public func contactsChanged() async {
        dirty = true
        await refresh()
    }

    public func retryLoading() async { await refresh(force: true) }

    // True means iOS will no longer show the permission dialog.
    public func requestAccess() async -> Bool {
        guard !requestingAccess else { return false }
        let current = repository.authorization()
        guard current == .notDetermined else {
            await refresh()
            return !current.canRead
        }
        requestingAccess = true
        defer { requestingAccess = false }
        do {
            try await repository.requestAccess()
            await refresh()
        } catch {
            await refresh()
            if repository.authorization() == .notDetermined { state = .failed }
        }
        return false
    }

    public func contact(id: String) -> ContactRecord? { contacts.first { $0.id == id } }

    private func refresh(force: Bool = false) async {
        let current = repository.authorization()
        if current != authorization {
            authorization = current
            revision += 1
            loaded = false
        }
        guard current.canRead else {
            contacts = []
            visibleContacts = []
            loaded = false
            switch current {
            case .notDetermined: state = .permission
            case .restricted: state = .restricted
            default: state = .denied
            }
            return
        }
        guard force || dirty || !loaded else { return }
        if refreshing {
            if force { dirty = true }
            return
        }
        refreshing = true
        dirty = false
        let fetchRevision = revision
        state = .loading
        do {
            let result = try await repository.fetchContacts()
            if repository.authorization() == current && revision == fetchRevision {
                contacts = result.sorted {
                    let order = $0.displayName.localizedStandardCompare($1.displayName)
                    return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
                }
                loaded = true
                state = .loaded
                filterContacts()
            } else {
                dirty = true
            }
        } catch {
            contacts = []
            visibleContacts = []
            loaded = false
            state = .failed
        }
        refreshing = false
        if repository.authorization() != authorization || dirty { await refresh() }
    }

    private func filterContacts() {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = search.isEmpty ? contacts : contacts.filter {
            $0.displayName.range(of: search, options: [.caseInsensitive, .diacriticInsensitive],
                                locale: .current) != nil
        }
        visibleContacts = sort == .ascending ? matches : Array(matches.reversed())
    }
}
