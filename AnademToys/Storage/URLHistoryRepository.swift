import Foundation

@MainActor
final class URLHistoryRepository: ObservableObject {
    @Published private(set) var store: URLHistoryStore

    private let storageKey = "com.anadem.AnademToys.urlHistoryStore"
    private let defaults: UserDefaults

    var items: [URLHistoryItem] {
        store.items
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.store = Self.loadStore(defaults: defaults, storageKey: storageKey)
    }

    func add(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.items.insert(URLHistoryItem(urlString: trimmed), at: 0)
        persist()
    }

    func update(_ item: URLHistoryItem, note: String) {
        guard let index = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.items[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.items[index].updatedAt = Date()
        persist()
    }

    func delete(_ item: URLHistoryItem) {
        store.items.removeAll { $0.id == item.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder.urlHistoryStoreEncoder.encode(store) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadStore(defaults: UserDefaults, storageKey: String) -> URLHistoryStore {
        guard let data = defaults.data(forKey: storageKey) else {
            return .empty
        }

        guard let decoded = try? JSONDecoder.urlHistoryStoreDecoder.decode(URLHistoryStore.self, from: data) else {
            return .empty
        }

        return decoded
    }
}

private extension JSONEncoder {
    static var urlHistoryStoreEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var urlHistoryStoreDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
