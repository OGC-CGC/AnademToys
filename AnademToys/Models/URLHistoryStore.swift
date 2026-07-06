import Foundation

struct URLHistoryStore: Codable {
    var schemaVersion: Int
    var items: [URLHistoryItem]

    static let currentSchemaVersion = 1

    static var empty: URLHistoryStore {
        URLHistoryStore(schemaVersion: currentSchemaVersion, items: [])
    }
}
