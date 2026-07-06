import SwiftUI

struct URLHistoryRowView: View {
    let item: URLHistoryItem
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.displayTitle)
                        .font(.headline)

                    if let scheme = item.parsedScheme {
                        Text(scheme)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.trimmedURLString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.note.isEmpty {
                    Text(item.note)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .help("复制")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .help("编辑备注")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .help("删除")
            }
            .buttonStyle(.borderless)
            .font(.title3)
        }
        .padding(.vertical, 8)
    }
}
