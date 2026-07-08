import AppKit
import Foundation

@MainActor
final class ArchivePreviewViewModel: ObservableObject {
    @Published private(set) var archiveURL: URL?
    @Published private(set) var format: ArchiveFormat = .unknown
    @Published private(set) var entries: [ArchiveEntry] = []
    @Published private(set) var currentDirectoryPath = ""
    @Published private(set) var compressedFileSize: Int64?
    @Published private(set) var isLoading = false
    @Published private(set) var iconCacheVersion = 0
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let reader: ArchiveReading
    private let iconCache: ArchiveEntryIconCache
    private var archiveIndex: ArchiveIndex?
    private var indexTask: Task<Void, Never>?
    private var iconTask: Task<Void, Never>?

    init(reader: ArchiveReading = LibArchiveReader(), iconCache: ArchiveEntryIconCache = .shared) {
        self.reader = reader
        self.iconCache = iconCache
    }

    var filteredEntries: [ArchiveEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedStandardContains(query) || $0.path.localizedStandardContains(query)
        }
    }

    var fileCount: Int {
        entries.filter { !$0.isDirectory }.count
    }

    var directoryCount: Int {
        entries.filter(\.isDirectory).count
    }

    var totalFileCount: Int {
        archiveIndex?.totalFileCount ?? 0
    }

    var totalDirectoryCount: Int {
        archiveIndex?.totalDirectoryCount ?? 0
    }

    var compressionAlgorithm: String {
        archiveIndex?.compressionAlgorithm ?? "--"
    }

    var formattedCompressedFileSize: String {
        guard let compressedFileSize else { return "--" }
        return ByteCountFormatter.string(fromByteCount: compressedFileSize, countStyle: .file)
    }

    var formattedTotalUncompressedSize: String {
        guard let totalUncompressedSize = archiveIndex?.totalUncompressedSize else { return "--" }
        return ByteCountFormatter.string(fromByteCount: totalUncompressedSize, countStyle: .file)
    }

    var displayDirectoryPath: String {
        currentDirectoryPath.isEmpty ? "/" : "/\(currentDirectoryPath)"
    }

    var canGoUp: Bool {
        !currentDirectoryPath.isEmpty
    }

    func chooseArchive() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "选择 libarchive 可识别的压缩包或归档镜像文件"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openArchive(url)
    }

    func openArchive(_ url: URL) {
        cancelIndexTask()
        isLoading = true
        errorMessage = nil
        archiveURL = url
        format = .unknown
        entries = []
        currentDirectoryPath = ""
        compressedFileSize = Self.fileSize(for: url)
        searchText = ""

        let reader = reader
        indexTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try reader.index(in: url) }
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.archiveURL == url else { return }
                self.isLoading = false

                switch result {
                case .success(let index):
                    self.archiveIndex = index
                    self.format = index.format
                    self.loadCurrentDirectory()
                case .failure(let error):
                    self.archiveURL = nil
                    self.archiveIndex = nil
                    self.format = .unknown
                    self.entries = []
                    self.compressedFileSize = nil
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func openDroppedArchives(_ urls: [URL]) {
        guard archiveURL == nil else { return }

        for url in urls {
            if (try? reader.format(of: url)) != nil {
                openArchive(url)
                return
            }
        }

        errorMessage = "请拖入 libarchive 可识别的压缩包或归档镜像文件。"
    }

    func enterDirectory(_ entry: ArchiveEntry) {
        guard entry.isDirectory else { return }
        currentDirectoryPath = entry.path
        searchText = ""
        loadCurrentDirectory()
    }

    func goUp() {
        guard canGoUp else { return }
        var components = currentDirectoryPath.split(separator: "/").map(String.init)
        components.removeLast()
        currentDirectoryPath = components.joined(separator: "/")
        searchText = ""
        loadCurrentDirectory()
    }

    func formattedSize(for entry: ArchiveEntry) -> String {
        guard entry.isDirectory else {
            return entry.formattedSize
        }

        if let size = archiveIndex?.size(for: entry.path) {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }

        if isLoading {
            return "统计中"
        }

        return "--"
    }

    func icon(for entry: ArchiveEntry) -> NSImage? {
        _ = iconCacheVersion
        return iconCache.icon(for: entry)
    }

    private func loadCurrentDirectory() {
        guard let archiveIndex else { return }

        errorMessage = nil
        entries = archiveIndex.entries(in: currentDirectoryPath)
        preloadIconsForCurrentDirectory()
    }

    private func cancelIndexTask() {
        indexTask?.cancel()
        indexTask = nil
        iconTask?.cancel()
        iconTask = nil
        archiveIndex = nil
    }

    private func preloadIconsForCurrentDirectory() {
        iconTask?.cancel()

        let missingKeys = iconCache.missingKeys(for: entries)
        guard !missingKeys.isEmpty else { return }

        let iconCache = iconCache
        iconTask = Task { [weak self] in
            for key in missingKeys {
                guard !Task.isCancelled else { return }

                let didLoad = iconCache.loadIconIfNeeded(forKey: key)
                guard !Task.isCancelled else { return }

                if didLoad {
                    self?.iconCacheVersion += 1
                    await Task.yield()
                }
            }
        }
    }

    private static func fileSize(for url: URL) -> Int64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return nil
        }

        return Int64(fileSize)
    }
}
