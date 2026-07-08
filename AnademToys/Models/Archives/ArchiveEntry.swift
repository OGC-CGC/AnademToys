import Foundation

struct ArchiveEntry: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let isDirectory: Bool
    let uncompressedSize: Int64?
    let modifiedAt: Date?
    let isVirtualDirectory: Bool

    init(
        path: String,
        name: String,
        isDirectory: Bool,
        uncompressedSize: Int64?,
        modifiedAt: Date?,
        isVirtualDirectory: Bool = false
    ) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.uncompressedSize = uncompressedSize
        self.modifiedAt = modifiedAt
        self.isVirtualDirectory = isVirtualDirectory
    }

    var id: String { path }

    var formattedSize: String {
        guard let uncompressedSize else {
            return isDirectory ? "--" : "未知"
        }

        return ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    var formattedModifiedAt: String {
        guard let modifiedAt else { return "--" }
        return modifiedAt.formatted(date: .numeric, time: .shortened)
    }
}
