import SwiftUI

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("通用") {
                LabeledContent("应用名称", value: "AnademToys")
                LabeledContent("数据存储", value: "本机 UserDefaults")
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("通用设置")
    }
}
