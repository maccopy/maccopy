import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipboardStore = .shared
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.5)
            itemList
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 400, height: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ── Search ────────────────────────────────────────────────────────────────

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            TextField("Search clipboard history…", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)

            if !store.searchQuery.isEmpty {
                Button {
                    store.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .onAppear { searchFocused = true }
    }

    // ── List ──────────────────────────────────────────────────────────────────

    @ViewBuilder
    private var itemList: some View {
        if store.filtered.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.filtered) { entry in
                        ClipboardRowView(
                            entry: entry,
                            onPaste: { store.paste(entry) },
                            onDelete: { store.delete(entry) }
                        )
                        .padding(.horizontal, 6)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: store.entries.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.tertiary)
            Text(store.entries.isEmpty ? "No clipboard history yet" : "No results for \"\(store.searchQuery)\"")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── Footer ────────────────────────────────────────────────────────────────

    private var footer: some View {
        HStack {
            Text("\(store.entries.count) item\(store.entries.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Clear All") {
                store.clear()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.tertiary)
                .font(.system(size: 11))

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
