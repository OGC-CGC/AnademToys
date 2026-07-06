import Foundation

@MainActor
final class URLSchemeRepository: ObservableObject {
    @Published private(set) var store: URLSchemeStore

    private let storageKey = "com.anadem.AnademToys.urlSchemeStore"
    private let defaults: UserDefaults

    var items: [URLSchemeItem] {
        store.items
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.store = Self.loadStore(defaults: defaults, storageKey: storageKey)
    }

    func add(name: String, urlString: String, note: String, isEnabled: Bool) {
        guard let scheme = URLSchemeItem.normalizedScheme(from: urlString) else { return }
        guard !store.items.contains(where: { $0.scheme == scheme }) else { return }

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? scheme : name
        let item = URLSchemeItem(name: finalName, urlString: scheme, note: note, isEnabled: isEnabled)
        store.items.insert(item, at: 0)
        persist()
    }

    func addFilter(from input: String) {
        guard let scheme = URLSchemeItem.normalizedScheme(from: input) else { return }
        add(name: scheme, urlString: scheme, note: "", isEnabled: true)
    }

    func update(_ item: URLSchemeItem, name: String, urlString: String, note: String, isEnabled: Bool) {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        guard let scheme = URLSchemeItem.normalizedScheme(from: urlString) else { return }
        guard !store.items.contains(where: { $0.id != item.id && $0.scheme == scheme }) else { return }

        store.items[index].name = name
        store.items[index].urlString = scheme
        store.items[index].note = note
        store.items[index].isEnabled = isEnabled
        store.items[index].updatedAt = Date()
        persist()
    }

    func delete(_ item: URLSchemeItem) {
        store.items.removeAll { $0.id == item.id }
        persist()
    }

    func setEnabled(_ item: URLSchemeItem, isEnabled: Bool) {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.items[index].isEnabled = isEnabled
        store.items[index].updatedAt = Date()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder.urlSchemeStoreEncoder.encode(store) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadStore(defaults: UserDefaults, storageKey: String) -> URLSchemeStore {
        guard let data = defaults.data(forKey: storageKey) else {
            return .empty
        }

        guard let decoded = try? JSONDecoder.urlSchemeStoreDecoder.decode(URLSchemeStore.self, from: data) else {
            return .empty
        }

        return decoded
    }
}

private extension JSONEncoder {
    static var urlSchemeStoreEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var urlSchemeStoreDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
