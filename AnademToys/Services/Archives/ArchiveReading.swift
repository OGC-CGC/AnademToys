import Foundation

struct ArchiveIndex: Sendable {
    let format: ArchiveFormat
    let compressionAlgorithm: String
    let totalFileCount: Int
    let totalDirectoryCount: Int
    let totalUncompressedSize: Int64
    let entriesByDirectory: [String: [ArchiveEntry]]
    let directorySizes: [String: Int64]

    func entries(in directoryPath: String) -> [ArchiveEntry] {
        entriesByDirectory[Self.normalizeDirectoryPath(directoryPath)] ?? []
    }

    func size(for directoryPath: String) -> Int64? {
        directorySizes[Self.normalizeDirectoryPath(directoryPath)]
    }

    private static func normalizeDirectoryPath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
            .joined(separator: "/")
    }
}

protocol ArchiveReading: Sendable {
    func format(of url: URL) throws -> ArchiveFormat
    func index(in url: URL) throws -> ArchiveIndex
    func entries(in url: URL, directoryPath: String) throws -> [ArchiveEntry]
    func directorySize(in url: URL, directoryPath: String) throws -> Int64
    func directorySizes(in url: URL, directoryPaths: Set<String>) throws -> [String: Int64]
}

enum ArchiveReadError: LocalizedError {
    case unsupportedFormat(ArchiveFormat)
    case libraryUnavailable
    case openFailed(String)
    case readFailed(String)
    case unsafePath(String)
    case entryLimitExceeded(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            "暂不支持该压缩格式: \(format.title)"
        case .libraryUnavailable:
            "未找到 libarchive。请将预编译 libarchive.xcframework 加入项目并随 App 一起嵌入。"
        case .openFailed(let message):
            "无法打开压缩文件: \(message)"
        case .readFailed(let message):
            "读取压缩文件失败: \(message)"
        case .unsafePath(let path):
            "压缩包包含不安全路径: \(path)"
        case .entryLimitExceeded(let limit):
            "压缩包条目数超过安全限制: \(limit)"
        }
    }
}
