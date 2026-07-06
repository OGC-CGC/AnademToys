import Foundation

enum HelperAppManager {
    static var helperURL: URL {
        applicationSupportDirectory
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("AnademToysTool.app", isDirectory: true)
    }

    static func applyEnabledSchemes(_ schemes: [String]) throws {
        let normalizedSchemes = schemes
            .compactMap { URLSchemeItem.normalizedScheme(from: $0) }
            .uniqued()
            .sorted()

        guard !normalizedSchemes.isEmpty else {
            AppLogger.log("Helper apply failed: no enabled schemes.")
            throw HelperAppError.noEnabledSchemes
        }

        AppLogger.log("Applying helper with schemes: \(normalizedSchemes.joined(separator: ", "))")
        let helperParentURL = helperURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: helperParentURL, withIntermediateDirectories: true)
        try removeLegacyHelperIfNeeded(in: helperParentURL)

        let scriptURL = helperParentURL.appendingPathComponent("AnademToysTool.applescript")
        let mainAppURL = Bundle.main.bundleURL
        try helperScript(mainAppPath: mainAppURL.path).write(to: scriptURL, atomically: true, encoding: .utf8)
        AppLogger.log("Helper script written: \(scriptURL.path)")
        AppLogger.log("Helper will forward callbacks to main app: \(mainAppURL.path)")

        if FileManager.default.fileExists(atPath: helperURL.path) {
            try FileManager.default.removeItem(at: helperURL)
            AppLogger.log("Removed existing helper: \(helperURL.path)")
        }

        try run("/usr/bin/osacompile", arguments: ["-o", helperURL.path, scriptURL.path])
        AppLogger.log("Helper app compiled: \(helperURL.path)")
        try writeURLTypes(normalizedSchemes, to: helperURL.appendingPathComponent("Contents/Info.plist"))
        AppLogger.log("Helper Info.plist updated.")
        try run("/usr/bin/codesign", arguments: ["--force", "--deep", "--sign", "-", helperURL.path])
        AppLogger.log("Helper ad-hoc signed.")
        try run(
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            arguments: ["-f", helperURL.path]
        )
        AppLogger.log("Helper registered with Launch Services.")
    }

    private static var applicationSupportDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("AnademToys", isDirectory: true)
    }

    private static func removeLegacyHelperIfNeeded(in helperParentURL: URL) throws {
        let legacyAppURL = helperParentURL.appendingPathComponent("AnademLinkReceiver.app", isDirectory: true)
        let legacyScriptURL = helperParentURL.appendingPathComponent("AnademLinkReceiver.applescript")

        if FileManager.default.fileExists(atPath: legacyAppURL.path) {
            try FileManager.default.removeItem(at: legacyAppURL)
            AppLogger.log("Removed legacy helper app: \(legacyAppURL.path)")
        }

        if FileManager.default.fileExists(atPath: legacyScriptURL.path) {
            try FileManager.default.removeItem(at: legacyScriptURL)
            AppLogger.log("Removed legacy helper script: \(legacyScriptURL.path)")
        }
    }

    private static func helperScript(mainAppPath: String) -> String {
        """
        on appendLog(messageText)
            set logPath to (POSIX path of (path to library folder from user domain)) & "Application Support/AnademToys/Logs/anademtoys.log"
            do shell script "/bin/mkdir -p " & quoted form of ((POSIX path of (path to library folder from user domain)) & "Application Support/AnademToys/Logs")
            do shell script "/bin/echo " & quoted form of ("[" & (do shell script "/bin/date -u +%Y-%m-%dT%H:%M:%SZ") & "] Helper: " & messageText) & " >> " & quoted form of logPath
        end appendLog

        on open location originalURL
            try
                appendLog("received URL: " & originalURL)
                set encodeCommand to "printf %s " & quoted form of originalURL & " | /usr/bin/python3 -c " & quoted form of "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=''))"
                set encodedURL to do shell script encodeCommand
                set callbackURL to "anademtoys:function-url-history-helper?URL=" & encodedURL
                appendLog("forwarding URL: " & callbackURL)
                appendLog("target main app: \(mainAppPath)")
                do shell script "/usr/bin/open -a " & quoted form of "\(mainAppPath)" & " " & quoted form of callbackURL
                appendLog("forward command completed")
            on error errorMessage number errorNumber
                appendLog("error " & errorNumber & ": " & errorMessage)
            end try
        end open location
        """
    }

    private static func writeURLTypes(_ schemes: [String], to infoPlistURL: URL) throws {
        let data = try Data(contentsOf: infoPlistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw HelperAppError.invalidInfoPlist
        }

        plist["CFBundleIdentifier"] = "com.anadem.AnademToys.Tool"
        plist["CFBundleName"] = "AnademToysTool"
        plist["LSUIElement"] = true
        plist["CFBundleURLTypes"] = [
            [
                "CFBundleURLName": "AnademToys Link Receiver",
                "CFBundleURLSchemes": schemes
            ]
        ]

        let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try updatedData.write(to: infoPlistURL, options: .atomic)
    }

    private static func run(_ launchPath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? ""
            AppLogger.log("Command failed: \(launchPath) \(arguments.joined(separator: " ")) \(message)")
            throw HelperAppError.commandFailed(launchPath, message)
        }
        AppLogger.log("Command succeeded: \(launchPath) \(arguments.joined(separator: " "))")
    }
}

enum HelperAppError: LocalizedError {
    case noEnabledSchemes
    case invalidInfoPlist
    case commandFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .noEnabledSchemes:
            return "没有启用的监听 scheme。"
        case .invalidInfoPlist:
            return "无法读取 helper app 的 Info.plist。"
        case .commandFailed(let command, let message):
            return "\(command) 执行失败。\(message)"
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
