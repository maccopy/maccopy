import SwiftUI

struct ContentView: View {
    @ObservedObject private var store: ClipboardStore = .shared
    @ObservedObject private var prefs = PreferencesManager.shared
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var selectedID: UUID?
    @FocusState private var searchFocused: Bool

    private var pinned: [ClipboardEntry] { store.filtered.filter { $0.isPinned } }
    private var unpinned: [ClipboardEntry] { store.filtered.filter { !$0.isPinned } }
    private var allFiltered: [ClipboardEntry] { store.filtered }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if updater.updateAvailable {
                updateBanner
            }
            Divider().opacity(0.3)
            itemList
            Divider().opacity(0.3)
            footer
        }
        .frame(width: prefs.popoverWidth, height: 540)
        .background(
            Group {
                if prefs.useGlassEffect {
                    Rectangle().fill(.regularMaterial)
                } else {
                    Rectangle().fill(Color(NSColor.windowBackgroundColor))
                }
            }
            .opacity(prefs.overlayOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            searchFocused = true
            selectedID = allFiltered.first?.id
        }
        .onChange(of: store.searchQuery) {
            selectedID = allFiltered.first?.id
        }
        .sheet(isPresented: $updater.showChangelog) {
            if let release = updater.latestRelease {
                ChangelogView(release: release)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 13, weight: .medium))

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
                .transition(.opacity.combined(with: .scale(0.8)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Update Banner

    private var updateBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 1) {
                Text("Update available: v\(updater.latestRelease?.versionDisplay ?? "")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                if let date = updater.latestRelease?.formattedDate {
                    Text("Released \(date)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("Changelog") {
                updater.showChangelog = true
            }
            .buttonStyle(BannerButtonStyle(tint: .accentColor))

            Button("Update") {
                updater.openReleasePage()
            }
            .buttonStyle(BannerButtonStyle(tint: .green))

            Button {
                withAnimation { updater.dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.08))
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
                            sectionHeader("Pinned", icon: "pin.fill", color: .orange)
                        }
                    }

                    if !unpinned.isEmpty {
                        Section {
                            ForEach(unpinned) { entry in
                                rowView(entry)
                            }
                        } header: {
                            if !pinned.isEmpty {
                                sectionHeader("Recent", icon: "clock", color: .secondary)
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
                .onKeyPress(.upArrow) {
                    if selectedID == allFiltered.first?.id {
                        searchFocused = true
                        return .handled
                    }
                    return .ignored
                }
                .onChange(of: selectedID) {
                    if let id = selectedID { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .textCase(nil)
            .padding(.vertical, 2)
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
        VStack(spacing: 14) {
            Image(systemName: store.entries.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 4) {
                Text(store.entries.isEmpty ? "No clipboard history yet" : "No results")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                if !store.searchQuery.isEmpty {
                    Text("for \"\(store.searchQuery)\"")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Copy something to get started")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Text(countLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 2) {
                footerButton("Preferences", icon: "gearshape") {
                    AppDelegate.shared?.openPreferences()
                }
                footerDivider
                footerButton("Clear", icon: "trash") {
                    store.clear()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var countLabel: String {
        let total = store.entries.count
        let pinCount = store.entries.filter { $0.isPinned }.count
        if pinCount > 0 {
            return "\(total) items · \(pinCount) pinned"
        }
        return "\(total) item\(total == 1 ? "" : "s")"
    }

    private func footerButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9))
                Text(title)
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var footerDivider: some View {
        Text("·")
            .foregroundStyle(.quaternary)
            .font(.system(size: 11))
    }

    // MARK: - Helpers

    private func pasteSelected() {
        let target =
            selectedID.flatMap { id in allFiltered.first { $0.id == id } }
            ?? allFiltered.first
        if let entry = target { store.paste(entry) }
    }
}

// MARK: - Banner Button Style

private struct BannerButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(configuration.isPressed ? 0.22 : 0.12))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Changelog Sheet

struct ChangelogView: View {
    let release: GitHubRelease
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("What's new in v\(release.versionDisplay)")
                        .font(.system(size: 15, weight: .semibold))
                    if let date = release.formattedDate {
                        Text("Released \(date)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            // Changelog body
            ScrollView {
                Text(release.changelog)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button("View on GitHub") {
                    UpdateChecker.shared.openReleasePage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Dismiss") {
                    UpdateChecker.shared.dismiss()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

                Button("Download Update") {
                    UpdateChecker.shared.openReleasePage()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 500, height: 420)
    }
}
