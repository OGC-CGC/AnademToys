import SwiftUI

struct AppShellView: View {
    @State private var selectedModule: FeatureModule = .urlSchemes
    @StateObject private var archivePreviewViewModel = ArchivePreviewViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedModule: $selectedModule)
        } detail: {
            switch selectedModule {
            case .urlSchemes:
                URLSchemesView()
            case .archives:
                ArchivesView(viewModel: archivePreviewViewModel)
            case .generalSettings:
                GeneralSettingsView()
            case .about:
                AboutView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .urlSchemeCaptured)) { _ in
            selectedModule = .urlSchemes
        }
        .onReceive(NotificationCenter.default.publisher(for: .archiveOpenRequested)) { _ in
            selectedModule = .archives
        }
        .background(MainWindowAccessor())
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AnademToys")
                .font(.largeTitle.bold())
            Text("一个面向 macOS 的原生工具集合。")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Link("OGC-CGC/AnademToys", destination: URL(string: "https://github.com/OGC-CGC/AnademToys")!)
                LabeledContent("项目许可证", value: "GPL-3.0")
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 10) {
                Text("依赖许可证")
                    .font(.headline)
                Link("libarchive", destination: URL(string: "https://www.libarchive.org/")!)
                LabeledContent("许可证", value: "BSD 2-Clause")
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .navigationTitle("关于")
    }
}
