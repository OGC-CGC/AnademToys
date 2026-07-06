import Foundation

struct URLSchemeItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var urlString: String
    var note: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        note: String = "",
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.note = note
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedURLString: String {
        urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedScheme: String? {
        Self.normalizedScheme(from: urlString)
    }

    var displayName: String {
        if !trimmedName.isEmpty {
            return trimmedName
        }

        return parsedScheme ?? "未命名"
    }

    var scheme: String {
        parsedScheme ?? trimmedURLString
    }

    static func parsedScheme(from uriString: String) -> String? {
        let trimmed = uriString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: ":") else { return nil }

        let scheme = String(trimmed[..<separatorIndex])
        guard let firstScalar = scheme.unicodeScalars.first else { return nil }
        guard CharacterSet.letters.contains(firstScalar) else { return nil }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-.")
        guard scheme.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else { return nil }

        return scheme.lowercased()
    }

    static func normalizedScheme(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let parsed = parsedScheme(from: trimmed) {
            return parsed
        }

        return isValidScheme(trimmed) ? trimmed.lowercased() : nil
    }

    static func isValidScheme(_ scheme: String) -> Bool {
        guard let firstScalar = scheme.unicodeScalars.first else { return false }
        guard CharacterSet.letters.contains(firstScalar) else { return false }

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-.")
        return scheme.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    static func isValidURI(_ uriString: String) -> Bool {
        let trimmed = uriString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard parsedScheme(from: trimmed) != nil else { return false }
        return URL(string: trimmed) != nil
    }
}
