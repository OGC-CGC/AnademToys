import Darwin
import Foundation

final class LibArchiveReader: ArchiveReading, @unchecked Sendable {
    private enum Constants {
        static let archiveOK: Int32 = 0
        static let archiveEOF: Int32 = 1
        static let directoryFileType: Int32 = 0o040000
        static let maximumEntryCount = 1_048_570
        static let maximumPathByteCount = 1020
        static let maximumFilenameByteCount = 255
        static let archiveFormatBaseMask: Int32 = 0xFF0000
        static let archiveFormatTar: Int32 = 0x30000
        static let archiveFormatZip: Int32 = 0x50000
        static let archiveFormat7Zip: Int32 = 0x70000
    }

    private let library: LibArchiveLibrary

    init(library: LibArchiveLibrary = .shared) {
        self.library = library
    }

    func format(of url: URL) throws -> ArchiveFormat {
        try openArchive(url) { archive in
            var entry: OpaquePointer?
            let result = library.archiveReadNextHeader(archive, &entry)

            if result != Constants.archiveOK && result != Constants.archiveEOF {
                throw ArchiveReadError.openFailed(library.errorString(for: archive))
            }

            let format = detectedFormat(for: archive)
            if result == Constants.archiveOK {
                _ = library.archiveReadDataSkip(archive)
            }

            guard format != .unknown else {
                throw ArchiveReadError.unsupportedFormat(.unknown)
            }

            return format
        }
    }

    func entries(in url: URL, directoryPath: String) throws -> [ArchiveEntry] {
        try index(in: url).entries(in: directoryPath)
    }

    func index(in url: URL) throws -> ArchiveIndex {
        var archiveFormat: ArchiveFormat = .unknown
        var compressionAlgorithm = ""
        var entriesByDirectory: [String: [String: ArchiveEntry]] = [:]
        var directorySizes: [String: Int64] = [:]

        try scan(url) { archive, archiveEntry in
            if archiveFormat == .unknown {
                archiveFormat = detectedFormat(for: archive)
                compressionAlgorithm = detectedCompressionAlgorithm(for: archive, format: archiveFormat)
            }

            Self.addIndexEntries(for: archiveEntry, entriesByDirectory: &entriesByDirectory, directorySizes: &directorySizes)
        }

        guard archiveFormat != .unknown else {
            throw ArchiveReadError.unsupportedFormat(.unknown)
        }

        let sortedEntriesByDirectory = entriesByDirectory.mapValues { entriesByPath in
            entriesByPath.values.sorted(by: Self.areEntriesInDisplayOrder)
        }
        let totals = Self.totals(from: entriesByDirectory)

        return ArchiveIndex(
            format: archiveFormat,
            compressionAlgorithm: compressionAlgorithm.isEmpty ? archiveFormat.title : compressionAlgorithm,
            totalFileCount: totals.fileCount,
            totalDirectoryCount: totals.directoryCount,
            totalUncompressedSize: totals.uncompressedSize,
            entriesByDirectory: sortedEntriesByDirectory,
            directorySizes: directorySizes
        )
    }

    func directorySize(in url: URL, directoryPath: String) throws -> Int64 {
        try directorySizes(in: url, directoryPaths: [directoryPath])[directoryPath] ?? 0
    }

    func directorySizes(in url: URL, directoryPaths: Set<String>) throws -> [String: Int64] {
        let targetDirectories = Set(directoryPaths.map(Self.normalizeDirectoryPath))
        var sizes = Dictionary(uniqueKeysWithValues: targetDirectories.map { ($0, Int64(0)) })
        guard !targetDirectories.isEmpty else { return sizes }

        try scan(url) { _, archiveEntry in
            guard !archiveEntry.isDirectory, let size = archiveEntry.uncompressedSize else { return }

            for targetDirectory in targetDirectories where Self.isDescendant(archiveEntry.path, of: targetDirectory) {
                sizes[targetDirectory, default: 0] += size
            }
        }

        return sizes
    }

    private func scan(_ url: URL, handleEntry: (OpaquePointer, ArchiveEntry) throws -> Void) throws {
        try openArchive(url) { archive in
            var scannedEntryCount = 0

            while true {
                var entry: OpaquePointer?
                let result = library.archiveReadNextHeader(archive, &entry)
                if result == Constants.archiveEOF {
                    break
                }

                guard result == Constants.archiveOK, let entry else {
                    throw ArchiveReadError.readFailed(library.errorString(for: archive))
                }

                guard detectedFormat(for: archive) != .unknown else {
                    throw ArchiveReadError.unsupportedFormat(.unknown)
                }

                scannedEntryCount += 1
                guard scannedEntryCount <= Constants.maximumEntryCount else {
                    throw ArchiveReadError.entryLimitExceeded(Constants.maximumEntryCount)
                }

                if let archiveEntry = try makeEntry(from: entry) {
                    try handleEntry(archive, archiveEntry)
                }

                _ = library.archiveReadDataSkip(archive)
            }
        }
    }

    private func openArchive<T>(_ url: URL, body: (OpaquePointer) throws -> T) throws -> T {
        let archive = try library.archiveReadNew()
        defer {
            _ = library.archiveReadClose(archive)
            _ = library.archiveReadFree(archive)
        }

        try configure(archive)

        let openResult = url.path.withCString { path in
            library.archiveReadOpenFilename(archive, path, 10240)
        }
        guard openResult == Constants.archiveOK else {
            throw ArchiveReadError.openFailed(library.errorString(for: archive))
        }

        return try body(archive)
    }

    private func configure(_ archive: OpaquePointer) throws {
        guard library.archiveReadSupportFilterAll(archive) == Constants.archiveOK else {
            throw ArchiveReadError.readFailed(library.errorString(for: archive))
        }

        guard library.archiveReadSupportFormatZip(archive) == Constants.archiveOK,
              library.archiveReadSupportFormatTar(archive) == Constants.archiveOK,
              library.archiveReadSupportFormat7Zip(archive) == Constants.archiveOK else {
            throw ArchiveReadError.readFailed(library.errorString(for: archive))
        }
    }

    private func detectedFormat(for archive: OpaquePointer) -> ArchiveFormat {
        let formatCode = library.archiveFormat(archive) & Constants.archiveFormatBaseMask
        switch formatCode {
        case Constants.archiveFormatZip:
            return .zip
        case Constants.archiveFormatTar:
            return .tar
        case Constants.archiveFormat7Zip:
            return .sevenZip
        default:
            break
        }

        guard let formatName = library.archiveFormatName(archive)?.lowercased() else {
            return .unknown
        }

        if formatName.contains("zip") {
            return .zip
        }
        if formatName.contains("tar") {
            return .tar
        }
        if formatName.contains("7-zip") || formatName.contains("7zip") {
            return .sevenZip
        }

        return .unknown
    }

    private func detectedCompressionAlgorithm(for archive: OpaquePointer, format: ArchiveFormat) -> String {
        let filterNames = (0..<library.archiveFilterCount(archive)).compactMap { index -> String? in
            guard let name = library.archiveFilterName(archive, index)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty,
                  name.lowercased() != "none" else {
                return nil
            }

            return name
        }

        guard !filterNames.isEmpty else {
            return library.archiveFormatName(archive) ?? format.title
        }

        return (filterNames + [format.title]).joined(separator: " + ")
    }

    private func makeEntry(from entry: OpaquePointer) throws -> ArchiveEntry? {
        guard let pathPointer = library.archiveEntryPathname(entry) else { return nil }

        let rawPath = String(cString: pathPointer)
        let path = try Self.safeNormalizedPath(rawPath)
        guard !path.isEmpty else { return nil }

        let name = path.split(separator: "/").last.map(String.init) ?? path
        let isDirectory = library.archiveEntryFiletype(entry) == Constants.directoryFileType || rawPath.hasSuffix("/")
        let rawSize = library.archiveEntrySizeIsSet(entry) != 0 ? library.archiveEntrySize(entry) : nil
        let size = rawSize.flatMap { $0 >= 0 ? $0 : nil }
        let modifiedAt = library.archiveEntryMTimeIsSet(entry) != 0
            ? Date(timeIntervalSince1970: TimeInterval(library.archiveEntryMTime(entry)))
            : nil

        return ArchiveEntry(
            path: path,
            name: name.isEmpty ? path : name,
            isDirectory: isDirectory,
            uncompressedSize: size,
            modifiedAt: modifiedAt
        )
    }

    private static func safeNormalizedPath(_ rawPath: String) throws -> String {
        let normalizedSeparators = rawPath.replacingOccurrences(of: "\\", with: "/")
        let trimmedPath = normalizedSeparators.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard trimmedPath.utf8.count <= Constants.maximumPathByteCount else {
            throw ArchiveReadError.unsafePath(rawPath)
        }

        guard !normalizedSeparators.hasPrefix("/"),
              !normalizedSeparators.hasPrefix("\\"),
              !hasWindowsDrivePrefix(normalizedSeparators) else {
            throw ArchiveReadError.unsafePath(rawPath)
        }

        let components = trimmedPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        for component in components {
            guard component != ".", component != "..", component.utf8.count <= Constants.maximumFilenameByteCount else {
                throw ArchiveReadError.unsafePath(rawPath)
            }
        }

        return components.joined(separator: "/")
    }

    private static func visibleEntry(from entry: ArchiveEntry, in directoryPath: String) -> ArchiveEntry? {
        let entryComponents = components(for: entry.path)
        let directoryComponents = components(for: directoryPath)

        guard entryComponents.count > directoryComponents.count else { return nil }
        guard Array(entryComponents.prefix(directoryComponents.count)) == directoryComponents else { return nil }

        let visibleName = entryComponents[directoryComponents.count]
        let visiblePath = (directoryComponents + [visibleName]).joined(separator: "/")

        if entryComponents.count == directoryComponents.count + 1 {
            return entry
        }

        return ArchiveEntry(
            path: visiblePath,
            name: visibleName,
            isDirectory: true,
            uncompressedSize: nil,
            modifiedAt: nil,
            isVirtualDirectory: true
        )
    }

    private static func preferredEntry(existing: ArchiveEntry?, new: ArchiveEntry) -> ArchiveEntry {
        guard let existing else { return new }
        if existing.isVirtualDirectory && !new.isVirtualDirectory {
            return new
        }

        return existing
    }

    private static func addIndexEntries(
        for entry: ArchiveEntry,
        entriesByDirectory: inout [String: [String: ArchiveEntry]],
        directorySizes: inout [String: Int64]
    ) {
        let entryComponents = components(for: entry.path)
        guard !entryComponents.isEmpty else { return }

        if entryComponents.count > 1 {
            for depth in 1..<entryComponents.count {
                let directoryComponents = Array(entryComponents.prefix(depth))
                let directoryPath = directoryComponents.joined(separator: "/")
                let parentPath = Array(directoryComponents.dropLast()).joined(separator: "/")
                let directoryEntry = ArchiveEntry(
                    path: directoryPath,
                    name: directoryComponents.last ?? directoryPath,
                    isDirectory: true,
                    uncompressedSize: nil,
                    modifiedAt: nil,
                    isVirtualDirectory: true
                )

                entriesByDirectory[parentPath, default: [:]][directoryPath] = preferredEntry(
                    existing: entriesByDirectory[parentPath]?[directoryPath],
                    new: directoryEntry
                )
                directorySizes[directoryPath, default: 0] += 0
            }
        }

        let parentPath = Array(entryComponents.dropLast()).joined(separator: "/")
        entriesByDirectory[parentPath, default: [:]][entry.path] = preferredEntry(
            existing: entriesByDirectory[parentPath]?[entry.path],
            new: entry
        )

        if entry.isDirectory {
            directorySizes[entry.path, default: 0] += 0
            return
        }

        guard let size = entry.uncompressedSize else { return }

        for depth in 1..<entryComponents.count {
            let directoryPath = Array(entryComponents.prefix(depth)).joined(separator: "/")
            directorySizes[directoryPath, default: 0] += size
        }
    }

    private static func totals(from entriesByDirectory: [String: [String: ArchiveEntry]]) -> (fileCount: Int, directoryCount: Int, uncompressedSize: Int64) {
        var entriesByPath: [String: ArchiveEntry] = [:]
        for entries in entriesByDirectory.values {
            for (path, entry) in entries {
                entriesByPath[path] = preferredEntry(existing: entriesByPath[path], new: entry)
            }
        }

        var fileCount = 0
        var directoryCount = 0
        var uncompressedSize: Int64 = 0

        for entry in entriesByPath.values {
            if entry.isDirectory {
                directoryCount += 1
            } else {
                fileCount += 1
                uncompressedSize += entry.uncompressedSize ?? 0
            }
        }

        return (fileCount, directoryCount, uncompressedSize)
    }

    private static func areEntriesInDisplayOrder(_ lhs: ArchiveEntry, _ rhs: ArchiveEntry) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func isDescendant(_ path: String, of directoryPath: String) -> Bool {
        let directory = normalizeDirectoryPath(directoryPath)
        guard !directory.isEmpty else { return !path.isEmpty }
        return path.hasPrefix(directory + "/")
    }

    private static func normalizeDirectoryPath(_ path: String) -> String {
        components(for: path).joined(separator: "/")
    }

    private static func components(for path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    private static func hasWindowsDrivePrefix(_ path: String) -> Bool {
        guard path.count >= 2 else { return false }
        let characters = Array(path.prefix(2))
        return characters[1] == ":" && characters[0].isLetter
    }
}

final class LibArchiveLibrary: @unchecked Sendable {
    static let shared = LibArchiveLibrary()

    private typealias ArchiveReadNew = @convention(c) () -> OpaquePointer?
    private typealias ArchiveReadSupportFilterAll = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveReadSupportFormat = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveReadOpenFilename = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?, Int) -> Int32
    private typealias ArchiveReadNextHeader = @convention(c) (OpaquePointer?, UnsafeMutablePointer<OpaquePointer?>?) -> Int32
    private typealias ArchiveReadDataSkip = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveReadClose = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveReadFree = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveErrorString = @convention(c) (OpaquePointer?) -> UnsafePointer<CChar>?
    private typealias ArchiveFormatCode = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveFormatName = @convention(c) (OpaquePointer?) -> UnsafePointer<CChar>?
    private typealias ArchiveFilterCount = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveFilterName = @convention(c) (OpaquePointer?, Int32) -> UnsafePointer<CChar>?
    private typealias ArchiveEntryPathname = @convention(c) (OpaquePointer?) -> UnsafePointer<CChar>?
    private typealias ArchiveEntryFiletype = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveEntrySizeIsSet = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveEntrySize = @convention(c) (OpaquePointer?) -> Int64
    private typealias ArchiveEntryMTimeIsSet = @convention(c) (OpaquePointer?) -> Int32
    private typealias ArchiveEntryMTime = @convention(c) (OpaquePointer?) -> Int

    private var handle: UnsafeMutableRawPointer?

    private lazy var readNew: ArchiveReadNew? = symbol("archive_read_new")
    private lazy var readSupportFilterAll: ArchiveReadSupportFilterAll? = symbol("archive_read_support_filter_all")
    private lazy var readSupportFormatZip: ArchiveReadSupportFormat? = symbol("archive_read_support_format_zip")
    private lazy var readSupportFormatTar: ArchiveReadSupportFormat? = symbol("archive_read_support_format_tar")
    private lazy var readSupportFormat7Zip: ArchiveReadSupportFormat? = symbol("archive_read_support_format_7zip")
    private lazy var readOpenFilename: ArchiveReadOpenFilename? = symbol("archive_read_open_filename")
    private lazy var readNextHeader: ArchiveReadNextHeader? = symbol("archive_read_next_header")
    private lazy var readDataSkip: ArchiveReadDataSkip? = symbol("archive_read_data_skip")
    private lazy var readClose: ArchiveReadClose? = symbol("archive_read_close")
    private lazy var readFree: ArchiveReadFree? = symbol("archive_read_free")
    private lazy var archiveErrorString: ArchiveErrorString? = symbol("archive_error_string")
    private lazy var archiveFormatCode: ArchiveFormatCode? = symbol("archive_format")
    private lazy var archiveFormatNamePointer: ArchiveFormatName? = symbol("archive_format_name")
    private lazy var archiveFilterCountPointer: ArchiveFilterCount? = symbol("archive_filter_count")
    private lazy var archiveFilterNamePointer: ArchiveFilterName? = symbol("archive_filter_name")
    private lazy var entryPathname: ArchiveEntryPathname? = symbol("archive_entry_pathname")
    private lazy var entryFiletype: ArchiveEntryFiletype? = symbol("archive_entry_filetype")
    private lazy var entrySizeIsSet: ArchiveEntrySizeIsSet? = symbol("archive_entry_size_is_set")
    private lazy var entrySize: ArchiveEntrySize? = symbol("archive_entry_size")
    private lazy var entryMTimeIsSet: ArchiveEntryMTimeIsSet? = symbol("archive_entry_mtime_is_set")
    private lazy var entryMTime: ArchiveEntryMTime? = symbol("archive_entry_mtime")

    private init() {
        handle = Self.openLibrary()
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    func archiveReadNew() throws -> OpaquePointer {
        guard let readNew, let archive = readNew() else {
            throw ArchiveReadError.libraryUnavailable
        }

        return archive
    }

    func archiveReadSupportFilterAll(_ archive: OpaquePointer) -> Int32 {
        readSupportFilterAll?(archive) ?? -1
    }

    func archiveReadSupportFormatZip(_ archive: OpaquePointer) -> Int32 {
        readSupportFormatZip?(archive) ?? -1
    }

    func archiveReadSupportFormatTar(_ archive: OpaquePointer) -> Int32 {
        readSupportFormatTar?(archive) ?? -1
    }

    func archiveReadSupportFormat7Zip(_ archive: OpaquePointer) -> Int32 {
        readSupportFormat7Zip?(archive) ?? -1
    }

    func archiveReadOpenFilename(_ archive: OpaquePointer, _ path: UnsafePointer<CChar>, _ blockSize: Int) -> Int32 {
        readOpenFilename?(archive, path, blockSize) ?? -1
    }

    func archiveReadNextHeader(_ archive: OpaquePointer, _ entry: UnsafeMutablePointer<OpaquePointer?>) -> Int32 {
        readNextHeader?(archive, entry) ?? -1
    }

    func archiveReadDataSkip(_ archive: OpaquePointer) -> Int32 {
        readDataSkip?(archive) ?? -1
    }

    func archiveReadClose(_ archive: OpaquePointer) -> Int32 {
        readClose?(archive) ?? -1
    }

    func archiveReadFree(_ archive: OpaquePointer) -> Int32 {
        readFree?(archive) ?? -1
    }

    func archiveEntryPathname(_ entry: OpaquePointer) -> UnsafePointer<CChar>? {
        entryPathname?(entry)
    }

    func archiveEntryFiletype(_ entry: OpaquePointer) -> Int32 {
        entryFiletype?(entry) ?? 0
    }

    func archiveEntrySizeIsSet(_ entry: OpaquePointer) -> Int32 {
        entrySizeIsSet?(entry) ?? 0
    }

    func archiveEntrySize(_ entry: OpaquePointer) -> Int64 {
        entrySize?(entry) ?? 0
    }

    func archiveEntryMTimeIsSet(_ entry: OpaquePointer) -> Int32 {
        entryMTimeIsSet?(entry) ?? 0
    }

    func archiveEntryMTime(_ entry: OpaquePointer) -> Int {
        entryMTime?(entry) ?? 0
    }

    func errorString(for archive: OpaquePointer) -> String {
        guard let message = archiveErrorString?(archive) else {
            return "libarchive 未返回错误信息。"
        }

        return String(cString: message)
    }

    func archiveFormat(_ archive: OpaquePointer) -> Int32 {
        archiveFormatCode?(archive) ?? 0
    }

    func archiveFormatName(_ archive: OpaquePointer) -> String? {
        guard let formatName = archiveFormatNamePointer?(archive) else { return nil }
        return String(cString: formatName)
    }

    func archiveFilterCount(_ archive: OpaquePointer) -> Int32 {
        max(archiveFilterCountPointer?(archive) ?? 0, 0)
    }

    func archiveFilterName(_ archive: OpaquePointer, _ index: Int32) -> String? {
        guard let filterName = archiveFilterNamePointer?(archive, index) else { return nil }
        return String(cString: filterName)
    }

    private func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static func openLibrary() -> UnsafeMutableRawPointer? {
        let bundledCandidates = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent("libarchive.framework/libarchive").path,
            Bundle.main.privateFrameworksURL?.appendingPathComponent("libarchive.dylib").path
        ].compactMap { $0 }

        for path in bundledCandidates {
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                return handle
            }
        }

        for name in ["libarchive.dylib", "libarchive.2.dylib", "/usr/lib/libarchive.dylib"] {
            if let handle = dlopen(name, RTLD_NOW | RTLD_LOCAL) {
                return handle
            }
        }

        return nil
    }
}
