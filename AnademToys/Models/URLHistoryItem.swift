import Foundation

struct URLHistoryItem: Identifiable, Codable, Equatable {
    var id: UUID
    var urlString: String
    var note: String
    var capturedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        urlString: String,
        note: String = "",
        capturedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        self.note = note
        self.capturedAt = capturedAt
        self.updatedAt = updatedAt
    }

    var trimmedURLString: String {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedScheme: String? {
        URLSchemeItem.parsedScheme(from: urlString)
    }

    var displayTitle: String {
        parsedScheme.map { "\($0) 链接" } ?? "历史链接"
    }
}
