import AppKit

@MainActor
enum MainWindowManager {
    private static weak var mainWindow: NSWindow?

    static func register(_ window: NSWindow) {
        if mainWindow == nil {
            mainWindow = window
            AppLogger.log("Main window registered: \(window.windowNumber)")
            return
        }

        guard let existingWindow = mainWindow else {
            mainWindow = window
            AppLogger.log("Main window re-registered: \(window.windowNumber)")
            return
        }

        guard existingWindow !== window else { return }

        AppLogger.log("Duplicate window detected: \(window.windowNumber); focusing main window \(existingWindow.windowNumber) and closing duplicate.")
        focus(existingWindow)
        window.close()
    }

    static func focusMainWindow() {
        if let window = mainWindow {
            focus(window)
            return
        }

        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            mainWindow = window
            AppLogger.log("Main window recovered from NSApp windows: \(window.windowNumber)")
            focus(window)
            return
        }

        AppLogger.log("Main window focus requested but no window was available.")
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func focus(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        AppLogger.log("Main window focused: \(window.windowNumber)")
    }
}
