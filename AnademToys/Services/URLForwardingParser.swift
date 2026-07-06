import Foundation

enum URLForwardingParser {
    static func historyURLString(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "anademtoys" else { return nil }

        let rawString = url.absoluteString
        AppLogger.log("Parsing forwarded URL: \(rawString)")
        let prefix = "anademtoys:function-url-history-helper?"
        guard rawString.hasPrefix(prefix) else {
            AppLogger.log("Forwarded URL rejected: missing expected prefix.")
            return nil
        }

        let query = String(rawString.dropFirst(prefix.count))
        guard let components = URLComponents(string: "anademtoys://history?\(query)") else {
            AppLogger.log("Forwarded URL rejected: query could not be parsed.")
            return nil
        }

        let value = components.queryItems?.first(where: { $0.name == "URL" })?.value
        AppLogger.log(value == nil ? "Forwarded URL rejected: URL query item missing." : "Forwarded URL query parsed.")
        return value
    }
}
