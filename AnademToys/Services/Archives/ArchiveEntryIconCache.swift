import AppKit
import Foundation

@MainActor
final class ArchiveEntryIconCache {
    static let shared = ArchiveEntryIconCache()

    private enum Constants {
        static let folderKey = "folder"
        static let fileKey = "file"
        static let extensionPrefix = "ext-"
    }

    private var imagesByKey: [String: NSImage] = [:]
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func icon(for entry: ArchiveEntry) -> NSImage? {
        imagesByKey[Self.cacheKey(for: entry)]
    }

    func missingKeys(for entries: [ArchiveEntry]) -> [String] {
        var seenKeys: Set<String> = []
        var missingKeys: [String] = []

        for entry in entries {
            let key = Self.cacheKey(for: entry)
            guard imagesByKey[key] == nil, !seenKeys.contains(key) else { continue }

            seenKeys.insert(key)
            missingKeys.append(key)
        }

        return missingKeys
    }

    func loadIconIfNeeded(forKey key: String) -> Bool {
        guard imagesByKey[key] == nil else { return false }

        if let image = loadImageFromDisk(forKey: key) {
            imagesByKey[key] = image
            return true
        }

        let image = systemIcon(forKey: key)
        imagesByKey[key] = image
        saveImageToDisk(image, forKey: key)
        return true
    }

    func clearPersistentCache() throws {
        imagesByKey.removeAll()

        let directoryURL = cacheDirectoryURL
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    private static func cacheKey(for entry: ArchiveEntry) -> String {
        guard !entry.isDirectory else { return Constants.folderKey }

        let pathExtension = URL(fileURLWithPath: entry.name).pathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !pathExtension.isEmpty else { return Constants.fileKey }
        return Constants.extensionPrefix + pathExtension
    }

    private func systemIcon(forKey key: String) -> NSImage {
        if key == Constants.folderKey {
            return NSImage(named: NSImage.folderName) ?? NSWorkspace.shared.icon(forFileType: "folder")
        }

        if key == Constants.fileKey {
            return NSWorkspace.shared.icon(forFileType: "")
        }

        if key.hasPrefix(Constants.extensionPrefix) {
            let fileExtension = String(key.dropFirst(Constants.extensionPrefix.count))
            return NSWorkspace.shared.icon(forFileType: fileExtension)
        }

        return NSWorkspace.shared.icon(forFileType: "")
    }

    private func loadImageFromDisk(forKey key: String) -> NSImage? {
        NSImage(contentsOf: cacheFileURL(forKey: key))
    }

    private func saveImageToDisk(_ image: NSImage, forKey key: String) {
        guard let data = pngData(for: image) else { return }

        do {
            try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: cacheFileURL(forKey: key), options: .atomic)
        } catch {
            return
        }
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func cacheFileURL(forKey key: String) -> URL {
        cacheDirectoryURL.appendingPathComponent(safeFilename(forKey: key)).appendingPathExtension("png")
    }

    private func safeFilename(forKey key: String) -> String {
        key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? Constants.fileKey
    }

    private var cacheDirectoryURL: URL {
        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.temporaryDirectory

        return applicationSupportURL
            .appendingPathComponent("AnademToys", isDirectory: true)
            .appendingPathComponent("IconCache", isDirectory: true)
    }
}
