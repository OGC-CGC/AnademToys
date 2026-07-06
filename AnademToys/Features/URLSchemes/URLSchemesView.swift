import AppKit
import SwiftUI

struct URLSchemesView: View {
    private enum URLSchemeTab: String, CaseIterable, Identifiable {
        case history
        case filters

        var id: String { rawValue }

        var title: String {
            switch self {
            case .history:
                "历史记录"
            case .filters:
                "监听列表"
            }
        }
    }

    @EnvironmentObject private var schemeRepository: URLSchemeRepository
    @EnvironmentObject private var historyRepository: URLHistoryRepository

    @State private var inputText = ""
    @State private var searchText = ""
    @State private var selectedTab: URLSchemeTab = .history
    @State private var historyItemBeingEdited: URLHistoryItem?
    @State private var helperStatusMessage = ""

    private var parsedInputScheme: String? {
        URLSchemeItem.normalizedScheme(from: inputText)
    }

    private var filteredHistoryItems: [URLHistoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return historyRepository.items }

        return historyRepository.items.filter { item in
            item.urlString.localizedStandardContains(query)
                || item.note.localizedStandardContains(query)
                || (item.parsedScheme?.localizedStandardContains(query) ?? false)
        }
    }

    private var filteredSchemeItems: [URLSchemeItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return schemeRepository.items }

        return schemeRepository.items.filter { item in
            item.name.localizedStandardContains(query)
                || item.urlString.localizedStandardContains(query)
                || item.note.localizedStandardContains(query)
                || (item.parsedScheme?.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabArea
        }
        .navigationTitle("URL Scheme")
        .sheet(item: $historyItemBeingEdited) { item in
            URLHistoryEditorView(item: item) { note in
                historyRepository.update(item, note: note)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addURLSchemeRequested)) { _ in
            selectedTab = .filters
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL Scheme")
                        .font(.title2.bold())
                    Text("输入完整链接或 scheme，将其解析为需要 helper 监听的 scheme。")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("输入链接或 scheme，例如 magnet:?xt=urn:btih:xxx", text: $inputText)
                        .textFieldStyle(.roundedBorder)

                    Text(inputHint)
                        .font(.caption)
                        .foregroundStyle(parsedInputScheme == nil && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .red : .secondary)
                }

                Button {
                    addFilter()
                } label: {
                    Label("加入监听", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedInputScheme == nil)
            }
        }
        .padding(24)
    }

    private var inputHint: String {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "会自动提取第一个冒号前的 scheme；也可以直接输入 magnet、obsidian 等 scheme。"
        }

        if let parsedInputScheme {
            return "将加入监听列表: \(parsedInputScheme)"
        }

        return "未识别到有效 scheme。scheme 需以字母开头，可包含字母、数字、+、-、."
    }

    private var tabArea: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                ForEach(URLSchemeTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 24)
            .padding(.top, 16)

            TextField("搜索历史或监听列表", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)

            Group {
                switch selectedTab {
                case .history:
                    historyCard
                case .filters:
                    filtersCard
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("历史记录")
                    .font(.headline)
                Spacer()
                Text("\(filteredHistoryItems.count) 条")
                    .foregroundStyle(.secondary)
            }

            if filteredHistoryItems.isEmpty {
                emptyState(
                    systemImage: "clock",
                    title: searchText.isEmpty ? "还没有历史记录" : "没有匹配的历史记录",
                    message: searchText.isEmpty ? "helper 转发来的链接会出现在这里。" : "尝试更换搜索关键词。"
                )
            } else {
                ScrollViewReader { scrollProxy in
                    List {
                        ForEach(filteredHistoryItems) { item in
                            URLHistoryRowView(
                                item: item,
                                onCopy: { copy(item.trimmedURLString) },
                                onEdit: { historyItemBeingEdited = item },
                                onDelete: { historyRepository.delete(item) }
                            )
                            .id(item.id)
                        }
                    }
                    .listStyle(.inset)
                    .onChange(of: historyRepository.items.count) { _, _ in
                        scrollToTopHistoryItem(using: scrollProxy)
                    }
                }
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("监听列表")
                    .font(.headline)
                Spacer()
                Button {
                    applyHelper()
                } label: {
                    Label("应用更改", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(schemeRepository.items.filter(\.isEnabled).isEmpty)
            }

            if !helperStatusMessage.isEmpty {
                Text(helperStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if filteredSchemeItems.isEmpty {
                emptyState(
                    systemImage: "link.badge.plus",
                    title: searchText.isEmpty ? "还没有监听 scheme" : "没有匹配的监听项",
                    message: searchText.isEmpty ? "在上方输入链接或 scheme 后加入监听列表。" : "尝试更换搜索关键词。"
                )
            } else {
                List {
                    ForEach(filteredSchemeItems) { item in
                        URLSchemeRowView(
                            item: item,
                            onEnabledChange: { schemeRepository.setEnabled(item, isEnabled: $0) },
                            onDelete: { schemeRepository.delete(item) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func scrollToTopHistoryItem(using scrollProxy: ScrollViewProxy) {
        guard selectedTab == .history, let topItemID = filteredHistoryItems.first?.id else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.18)) {
                scrollProxy.scrollTo(topItemID, anchor: .top)
            }
        }
    }

    private func addFilter() {
        schemeRepository.addFilter(from: inputText)
        inputText = ""
        selectedTab = .filters
    }

    private func applyHelper() {
        do {
            let schemes = schemeRepository.items
                .filter(\.isEnabled)
                .map(\.scheme)
            try HelperAppManager.applyEnabledSchemes(schemes)
            helperStatusMessage = "已刷新 helper: \(HelperAppManager.helperURL.path)"
            AppLogger.log("UI helper apply succeeded: \(HelperAppManager.helperURL.path)")
        } catch {
            helperStatusMessage = error.localizedDescription
            AppLogger.log("UI helper apply failed: \(error.localizedDescription)")
        }
    }
}
