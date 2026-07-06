import SwiftUI

@main
struct AnademToysApp: App {
    @StateObject private var urlSchemeRepository = URLSchemeRepository()
    @StateObject private var historyRepository = URLHistoryRepository()

    var body: some Scene {
        Window("AnademToys", id: "main") {
            AppShellView()
                .environmentObject(urlSchemeRepository)
                .environmentObject(historyRepository)
                .frame(minWidth: 920, minHeight: 620)
                .onAppear {
                    AppRegistrationManager.registerCurrentApp()
                }
                .onOpenURL { url in
                    AppLogger.log("Main app received URL: \(url.absoluteString)")
                    guard let urlString = URLForwardingParser.historyURLString(from: url) else {
                        AppLogger.log("Main app ignored URL because it is not a valid helper callback.")
                        return
                    }
                    AppLogger.log("Main app parsed history URL: \(urlString)")
                    historyRepository.add(urlString: urlString)
                    AppLogger.log("Main app saved URL into history.")
                    NotificationCenter.default.post(name: .urlSchemeCaptured, object: url)
                    MainWindowManager.focusMainWindow()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新增 URL Scheme") {
                    NotificationCenter.default.post(name: .addURLSchemeRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let addURLSchemeRequested = Notification.Name("addURLSchemeRequested")
    static let urlSchemeCaptured = Notification.Name("urlSchemeCaptured")
}
