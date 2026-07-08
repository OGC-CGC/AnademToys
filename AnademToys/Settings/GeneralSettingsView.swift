import SwiftUI

struct GeneralSettingsView: View {
    @State private var iconCacheRefreshMessage: String?

    var body: some View {
        Form {
            Section("通用") {
                LabeledContent("应用名称", value: "AnademToys")
                LabeledContent("数据存储", value: "本机 UserDefaults")
            }

            Section("文件图标缓存") {
                Button {
                    refreshIconCache()
                } label: {
                    Label("刷新文件图标缓存", systemImage: "arrow.clockwise")
                }

                if let iconCacheRefreshMessage {
                    Text(iconCacheRefreshMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("通用设置")
    }

    private func refreshIconCache() {
        do {
            try ArchiveEntryIconCache.shared.clearPersistentCache()
            iconCacheRefreshMessage = "文件图标缓存已刷新。"
        } catch {
            iconCacheRefreshMessage = "刷新失败: \(error.localizedDescription)"
        }
    }
}
