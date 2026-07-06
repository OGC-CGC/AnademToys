import SwiftUI

struct AppShellView: View {
    @State private var selectedModule: FeatureModule = .urlSchemes

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedModule: $selectedModule)
        } detail: {
            switch selectedModule {
            case .urlSchemes:
                URLSchemesView()
            case .generalSettings:
                GeneralSettingsView()
            case .about:
                AboutView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .urlSchemeCaptured)) { _ in
            selectedModule = .urlSchemes
        }
        .background(MainWindowAccessor())
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AnademToys")
                .font(.largeTitle.bold())
            Text("一个面向 macOS 的原生工具集合。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .navigationTitle("关于")
    }
}
