import Foundation

struct URLSchemeStore: Codable {
    var schemaVersion: Int
    var items: [URLSchemeItem]

    static let currentSchemaVersion = 1

    static var empty: URLSchemeStore {
        URLSchemeStore(schemaVersion: currentSchemaVersion, items: [])
    }
}
