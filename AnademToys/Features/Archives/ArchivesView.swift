import AppKit
import SwiftUI

struct ArchivesView: View {
    @ObservedObject var viewModel: ArchivePreviewViewModel
    @State private var selectedEntryID: ArchiveEntry.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .navigationTitle("压缩文件")
        .onReceive(NotificationCenter.default.publisher(for: .archiveOpenRequested)) { notification in
            guard let url = notification.object as? URL else { return }
            viewModel.openArchive(url)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let archiveURL = viewModel.archiveURL {
                archiveSummary(for: archiveURL)
            } else {
                Text("等待打开压缩文件")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }

    private func archiveSummary(for url: URL) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                summaryLabel("文件")
                Text(url.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            GridRow {
                summaryLabel("格式")
                Text(viewModel.format.title)
                summaryLabel("压缩算法")
                Text(viewModel.compressionAlgorithm)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            GridRow {
                summaryLabel("压缩后大小")
                Text(viewModel.formattedCompressedFileSize)
                    .monospacedDigit()
                summaryLabel("压缩前大小")
                Text(viewModel.formattedTotalUncompressedSize)
                    .monospacedDigit()
            }
            GridRow {
                summaryLabel("当前目录")
                Text(viewModel.displayDirectoryPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            GridRow {
                summaryLabel("文件统计")
                Text("当前目录 \(viewModel.fileCount) 个文件，\(viewModel.directoryCount) 个文件夹（共计 \(viewModel.totalFileCount) 个文件，\(viewModel.totalDirectoryCount) 个文件夹）")
            }
        }
        .font(.callout)
    }

    private func summaryLabel(_ value: String) -> some View {
        Text(value)
            .foregroundStyle(.secondary)
    }

    private var content: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    viewModel.goUp()
                } label: {
                    Label("上级", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canGoUp || viewModel.isLoading)

                TextField("搜索当前目录", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.chooseArchive()
                } label: {
                    Label("打开压缩包", systemImage: "archivebox")
                }
                .buttonStyle(.borderedProminent)
            }
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if viewModel.isLoading {
                ProgressView("正在读取压缩包")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                emptyState(systemImage: "exclamationmark.triangle", title: "无法读取压缩包", message: errorMessage)
            } else if viewModel.archiveURL == nil {
                emptyState(systemImage: "archivebox", title: "选择一个压缩包", message: "也可以直接拖入压缩包")
                    .dropDestination(for: URL.self) { urls, _ in
                        viewModel.openDroppedArchives(urls)
                        return true
                    }
            } else if viewModel.filteredEntries.isEmpty {
                emptyState(systemImage: "doc.text.magnifyingglass", title: "没有匹配的条目", message: "尝试更换搜索关键词。")
            } else {
                entriesTable
            }
        }
        .padding(.bottom, 24)
    }

    private var entriesTable: some View {
        Table(viewModel.filteredEntries, selection: $selectedEntryID) {
            TableColumn("名称") { entry in
                tableCell(alignment: .leading) {
                    HStack(spacing: 8) {
                        if let icon = viewModel.icon(for: entry) {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18, height: 18)
                        } else {
                            Color.clear
                                .frame(width: 18, height: 18)
                        }
                        Text(entry.name)
                            .lineLimit(1)
                    }
                }
            }

            TableColumn("路径") { entry in
                tableCell(alignment: .leading) {
                    Text(entry.path)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TableColumn("大小") { entry in
                tableCell(alignment: .trailing) {
                    Text(viewModel.formattedSize(for: entry))
                        .monospacedDigit()
                }
            }
            .width(min: 96, ideal: 120, max: 140)

            TableColumn("修改时间") { entry in
                tableCell(alignment: .trailing) {
                    Text(entry.formattedModifiedAt)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 140, ideal: 180, max: 220)
        }
        .background(
            TableDoubleClickBridge(rowCount: viewModel.filteredEntries.count) { row in
                guard viewModel.filteredEntries.indices.contains(row) else { return }
                viewModel.enterDirectory(viewModel.filteredEntries[row])
            }
        )
        .padding(.horizontal, 24)
    }

    private func tableCell<Content: View>(
        alignment: Alignment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func emptyState(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct TableDoubleClickBridge: NSViewRepresentable {
    let rowCount: Int
    let onDoubleClick: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(rowCount: rowCount, onDoubleClick: onDoubleClick)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        Task { @MainActor in
            context.coordinator.attach(toTableNear: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.rowCount = rowCount
        context.coordinator.onDoubleClick = onDoubleClick

        Task { @MainActor in
            context.coordinator.attach(toTableNear: nsView)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.detach()
        }
    }

    final class Coordinator: NSObject {
        var rowCount: Int
        var onDoubleClick: (Int) -> Void
        private weak var tableView: NSTableView?

        init(rowCount: Int, onDoubleClick: @escaping (Int) -> Void) {
            self.rowCount = rowCount
            self.onDoubleClick = onDoubleClick
        }

        @MainActor
        func attach(toTableNear view: NSView) {
            guard tableView == nil, let tableView = nearestTableView(from: view) else { return }
            self.tableView = tableView
            tableView.target = self
            tableView.doubleAction = #selector(handleDoubleClick(_:))
        }

        @MainActor
        func detach() {
            guard tableView?.target === self else { return }
            tableView?.target = nil
            tableView?.doubleAction = nil
            tableView = nil
        }

        @MainActor
        @objc private func handleDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0, row < rowCount else { return }
            onDoubleClick(row)
        }

        @MainActor
        private func nearestTableView(from view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let candidate = current {
                if let tableView = candidate as? NSTableView {
                    return tableView
                }

                if let tableView = descendantTableView(in: candidate) {
                    return tableView
                }

                current = candidate.superview
            }

            return nil
        }

        @MainActor
        private func descendantTableView(in view: NSView) -> NSTableView? {
            if let tableView = view as? NSTableView {
                return tableView
            }

            for subview in view.subviews {
                if let tableView = descendantTableView(in: subview) {
                    return tableView
                }
            }

            return nil
        }
    }
}
