import SwiftUI

struct URLHistoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var note: String

    private let item: URLHistoryItem
    private let onSave: (String) -> Void

    init(item: URLHistoryItem, onSave: @escaping (String) -> Void) {
        self.item = item
        self.onSave = onSave
        _note = State(initialValue: item.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑历史记录")
                .font(.title2.bold())

            Form {
                VStack(alignment: .leading, spacing: 6) {
                    Text("完整链接")
                        .foregroundStyle(.secondary)
                    Text(item.trimmedURLString)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                if let scheme = item.parsedScheme {
                    LabeledContent("Scheme", value: scheme)
                }

                TextField("备注", text: $note, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    onSave(note)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
