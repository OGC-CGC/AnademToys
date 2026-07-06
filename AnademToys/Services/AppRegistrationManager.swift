import Foundation

enum AppRegistrationManager {
    static func registerCurrentApp() {
        let appURL = Bundle.main.bundleURL
        AppLogger.log("Registering main app with Launch Services: \(appURL.path)")

        do {
            try run(
                "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                arguments: ["-f", appURL.path]
            )
            AppLogger.log("Main app registered with Launch Services.")
        } catch {
            AppLogger.log("Main app registration failed: \(error.localizedDescription)")
        }
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
            throw RegistrationError.commandFailed(launchPath, message)
        }
    }
}

enum RegistrationError: LocalizedError {
    case commandFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let message):
            return "\(command) 执行失败。\(message)"
        }
    }
}
