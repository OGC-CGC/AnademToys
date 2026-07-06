import Foundation

enum AppLogger {
    static func log(_ message: String) {
        let line = "[\(Self.timestamp)] \(message)\n"

        do {
            let directory = try logsDirectory()
            let fileURL = directory.appendingPathComponent("anademtoys.log")

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            try handle.close()
        } catch {
            NSLog("AnademToys log failed: \(error.localizedDescription)")
        }
    }

    static var logFileURL: URL {
        get throws {
            try logsDirectory().appendingPathComponent("anademtoys.log")
        }
    }

    private static func logsDirectory() throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = baseURL
            .appendingPathComponent("AnademToys", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static var timestamp: String {
        ISO8601DateFormatter().string(from: Date())
    }
}
