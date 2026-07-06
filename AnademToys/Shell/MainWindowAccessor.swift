import AppKit
import SwiftUI

@MainActor
struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        registerWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        registerWindow(for: nsView)
    }

    private func registerWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            MainWindowManager.register(window)
        }
    }
}
