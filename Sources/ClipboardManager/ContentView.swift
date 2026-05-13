import SwiftUI

struct ContentView: View {
    @ObservedObject private var store: ClipboardStore = .shared
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    private var pinned: [ClipboardEntry] { store.filtered.filter { $0.isPinned } }
    private var unpinned: [ClipboardEntry] { store.filtered.filter { !$0.isPinned } }
    private var allFiltered: [ClipboardEntry] { store.filtered }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.4)
            itemList
            Divider().opacity(0.4)
            footer
        }
        .frame(width: 440, height: 540)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            searchFocused = true
            selectedID = allFiltered.first?.id
        }
        .onChange(of: store.searchQuery) {
            selectedID = allFiltered.first?.id
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 14))

            TextField("Search clipboard history…", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onKeyPress(.return) {
                    pasteSelected()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    if selectedID == nil { selectedID = allFiltered.first?.id }
                    searchFocused = false
                    return .handled
                }
                .onKeyPress(.escape) {
                    if store.searchQuery.isEmpty {
                        AppDelegate.shared?.togglePopover()
                    } else {
                        store.searchQuery = ""
                    }
                    return .handled
                }

            if !store.searchQuery.isEmpty {
                Button {
                    store.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Item List

    @ViewBuilder
    private var itemList: some View {
        if allFiltered.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                List(selection: $selectedID) {
                    if !pinned.isEmpty {
                        Section {
                            ForEach(pinned) { entry in
                                rowView(entry)
                            }
                        } header: {
                            Label("Pinned", systemImage: "pin.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                                .textCase(nil)
                        }
                    }

                    if !unpinned.isEmpty {
                        Section {
                            ForEach(unpinned) { entry in
                                rowView(entry)
                            }
                        } header: {
                            if !pinned.isEmpty {
                                Text("Recent")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .textCase(nil)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .onKeyPress(.return) {
                    pasteSelected()
                    return .handled
                }
                .onKeyPress(.escape) {
                    searchFocused = true
                    return .handled
                }
                .onChange(of: selectedID) {
                    if let id = selectedID { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }
    }

    private func rowView(_ entry: ClipboardEntry) -> some View {
        ClipboardRowView(
            entry: entry,
            isSelected: selectedID == entry.id,
            onPaste: { store.paste(entry) },
            onDelete: { store.delete(entry) },
            onPin: { store.togglePin(entry) }
        )
        .tag(entry.id)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.entries.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text(
                store.entries.isEmpty
                    ? "No clipboard history yet"
                    : "No results for \"\(store.searchQuery)\""
            )
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Text(countLabel)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            footerButton("Preferences") { AppDelegate.shared?.openPreferences() }
            footerDot
            footerButton("Clear") { store.clear() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var countLabel: String {
        let total = store.entries.count
        let pinCount = store.entries.filter { $0.isPinned }.count
        if pinCount > 0 {
            return "\(total) items · \(pinCount) pinned"
        }
        return "\(total) item\(total == 1 ? "" : "s")"
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    private var footerDot: some View {
        Text("·")
            .foregroundStyle(.tertiary)
            .font(.system(size: 11))
            .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func pasteSelected() {
        let target =
            selectedID.flatMap { id in allFiltered.first { $0.id == id } }
            ?? allFiltered.first
        if let entry = target { store.paste(entry) }
    }
}
