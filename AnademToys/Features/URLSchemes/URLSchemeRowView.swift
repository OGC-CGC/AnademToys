import SwiftUI

struct URLSchemeRowView: View {
    let item: URLSchemeItem
    let onEnabledChange: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.displayName)
                        .font(.headline)

                    if let scheme = item.parsedScheme {
                        Text(scheme)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !item.isEnabled {
                        Text("已停用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("监听 \(item.scheme):")
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
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { onEnabledChange($0) }
                ))
                .labelsHidden()
                .help("启用监听")

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
