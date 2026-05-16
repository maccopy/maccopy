import SwiftUI

struct ContentView: View {
    @ObservedObject private var store: ClipboardStore = .shared
    @ObservedObject private var prefs = PreferencesManager.shared
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var selectedID: UUID?
    @State private var showClearConfirm = false
    @FocusState private var searchFocused: Bool

    private var pinned: [ClipboardEntry] { store.filtered.filter { $0.isPinned } }
    private var unpinned: [ClipboardEntry] { store.filtered.filter { !$0.isPinned } }
    private var allFiltered: [ClipboardEntry] { store.filtered }
    private var selectedEntry: ClipboardEntry? {
        selectedID.flatMap { id in allFiltered.first { $0.id == id } }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if updater.updateAvailable {
                updateBanner
            }
            Divider().opacity(0.3)
            itemList
            if let entry = selectedEntry, shouldShowPreview(entry) {
                Divider().opacity(0.3)
                previewPane(entry)
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .push(from: .top).combined(with: .opacity)
                    ))
            }
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
        .overlay { cmdNumberShortcuts }
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) { store.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let unpinned = store.entries.filter { !$0.isPinned }.count
            Text("This will remove \(unpinned) item\(unpinned == 1 ? "" : "s"). Pinned items are kept.")
        }
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
        .tint(prefs.accentColorTheme.color)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(searchFocused ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.5))
                .font(.system(size: 14, weight: .medium))
                .animation(.easeInOut(duration: 0.15), value: searchFocused)

            TextField("Search clipboard history…", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .onKeyPress(.return) {
                    pasteSelected()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    if selectedID == nil { selectedID = allFiltered.first?.id }
                    else { moveSelection(by: 1) }
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(0.75)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
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

            if updater.isDownloading {
                HStack(spacing: 5) {
                    ProgressView(value: updater.downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .tint(.green)
                    Text("\(Int(updater.downloadProgress * 100))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
            } else {
                Button("Install Update") {
                    updater.downloadAndInstall()
                }
                .buttonStyle(BannerButtonStyle(tint: .green))
            }

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
                List {
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
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onChange(of: selectedID) {
                    if let id = selectedID { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color.opacity(0.7))
            .textCase(nil)
            .padding(.vertical, 3)
            .padding(.horizontal, 2)
    }

    private func rowView(_ entry: ClipboardEntry) -> some View {
        let index = allFiltered.firstIndex(where: { $0.id == entry.id })
        return ClipboardRowView(
            entry: entry,
            isSelected: selectedID == entry.id,
            cmdIndex: (index != nil && index! < 9) ? index! + 1 : nil,
            onPaste: { store.paste(entry) },
            onDelete: { store.delete(entry) },
            onPin: { store.togglePin(entry) }
        )
        .tag(entry.id)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
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
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)
                Text(countLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            keyboardHints
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 2) {
                footerButton("Preferences", icon: "gearshape.fill") {
                    AppDelegate.shared?.openPreferences()
                }
                footerDivider
                footerButton("Clear", icon: "trash") {
                    showClearConfirm = true
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var keyboardHints: some View {
        HStack(spacing: 4) {
            hintKey("↑↓")
            hintKey("↩")
            hintKey("⎋")
        }
    }

    private func hintKey(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
            )
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

    private func moveSelection(by delta: Int) {
        let ids = allFiltered.map(\.id)
        guard !ids.isEmpty else { return }
        let current = selectedID.flatMap { ids.firstIndex(of: $0) } ?? -1
        let next = max(0, min(ids.count - 1, current + delta))
        selectedID = ids[next]
    }

    @ViewBuilder
    var cmdNumberShortcuts: some View {
        let digits: [Character] = ["1","2","3","4","5","6","7","8","9"]
        ForEach(0..<min(9, allFiltered.count), id: \.self) { index in
            Button("") { store.paste(allFiltered[index]) }
                .keyboardShortcut(KeyEquivalent(digits[index]), modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }

    private func shouldShowPreview(_ entry: ClipboardEntry) -> Bool {
        switch entry.type {
        case .text: return (entry.text?.count ?? 0) > 60
        case .image: return true
        case .file: return true
        }
    }

    @ViewBuilder
    private func previewPane(_ entry: ClipboardEntry) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch entry.type {
                case .text:
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(entry.text ?? "")
                            .font(.system(size: 11, design: entry.isURL ? .default : .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }

                case .image:
                    PreviewImageView(entry: entry)
                        .frame(maxWidth: .infinity)
                        .padding(6)

                case .file:
                    VStack(alignment: .leading, spacing: 4) {
                        Label(entry.fileName ?? "File", systemImage: "doc.fill")
                            .font(.system(size: 12, weight: .medium))
                        if let url = entry.fileURL {
                            Text(url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: 110)

            Button {
                if let text = entry.text {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
            .padding(6)
            .opacity(entry.type == .text ? 1 : 0)
        }
        .background(Color.primary.opacity(0.025))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedID)
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
    var isPostInstall: Bool = false
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

                if !isPostInstall {
                    Button("Install Update") {
                        dismiss()
                        UpdateChecker.shared.downloadAndInstall()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(UpdateChecker.shared.isDownloading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - Preview Image View

private struct PreviewImageView: View {
    let entry: ClipboardEntry
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 24))
            }
        }
        .task(id: entry.id) {
            image = await ClipboardStore.shared.loadImage(for: entry)
        }
    }
}

// MARK: - Post-install Changelog Window

import AppKit

@MainActor
final class ChangelogWindowController {
    private static var window: NSWindow?

    static func show(release: GitHubRelease) {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "What's New"
        w.isReleasedWhenClosed = false
        w.appearance = PreferencesManager.shared.appearanceMode.nsAppearance
        w.center()
        w.contentView = NSHostingView(
            rootView: ChangelogView(release: release, isPostInstall: true)
                .tint(PreferencesManager.shared.accentColorTheme.color)
        )
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
