import SwiftUI

struct ClipboardRowView: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void

    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?
    @State private var faviconImage: NSImage?

    private var timeAgo: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: entry.date, relativeTo: Date())
    }

    private var fontSize: CGFloat { prefs.rowDensity.primaryFontSize }
    private var vPad: CGFloat { prefs.rowDensity.verticalPadding }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if prefs.showTypeIcon {
                typeIndicator
            }
            contentArea
            Spacer(minLength: 4)
            if isHovered || isSelected {
                actionButtons
                    .transition(.opacity.combined(with: .scale(scale: 0.88, anchor: .trailing)))
            }
        }
        .padding(.vertical, vPad)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onPaste)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
        .task(id: entry.id) {
            if entry.type == .image {
                thumbnailImage = ClipboardStore.shared.loadImage(for: entry)
            }
        }
        .task(id: entry.linkPreview?.faviconURL) {
            guard entry.isURL, let urlStr = entry.linkPreview?.faviconURL else { return }
            faviconImage = await loadFaviconImage(from: urlStr)
        }
        .task(id: entry.isURL && entry.linkPreview == nil) {
            guard entry.isURL, entry.linkPreview == nil,
                let urlStr = entry.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            else { return }
            guard let preview = await LinkPreviewFetcher.shared.fetch(urlString: urlStr) else {
                return
            }
            await MainActor.run {
                ClipboardStore.shared.updateLinkPreview(id: entry.id, preview: preview)
            }
        }
    }

    // MARK: - Type Indicator

    @ViewBuilder
    private var typeIndicator: some View {
        switch entry.type {
        case .text:
            if entry.isURL {
                urlFaviconIndicator
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(width: 26)
            }

        case .image:
            Group {
                if let img = thumbnailImage {
                    Image(nsImage: img)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )

        case .file:
            fileTypeIndicator
        }
    }

    @ViewBuilder
    private var urlFaviconIndicator: some View {
        Group {
            if let img = faviconImage {
                Image(nsImage: img)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue.opacity(0.7))
            }
        }
        .frame(width: 26)
    }

    @ViewBuilder
    private var fileTypeIndicator: some View {
        if let ext = entry.fileExtension {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fileTypeColor(ext).opacity(0.12))
                Text(String(ext.prefix(4)))
                    .font(.system(size: ext.count <= 3 ? 8 : 7, weight: .semibold))
                    .foregroundStyle(fileTypeColor(ext))
            }
            .frame(width: 26, height: 20)
        } else {
            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue.opacity(0.7))
                .frame(width: 26)
        }
    }

    private func fileTypeColor(_ ext: String) -> Color {
        switch ext.lowercased() {
        case "pdf": return .red
        case "zip", "gz", "tar", "rar", "7z": return .purple
        case "mp4", "mov", "avi", "mkv", "m4v": return .blue
        case "mp3", "wav", "aac", "flac", "m4a": return .green
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "tiff": return .orange
        case "swift", "py", "js", "ts", "rs", "go", "kt", "java", "cpp", "c": return .mint
        case "doc", "docx": return .blue
        case "xls", "xlsx": return .green
        case "ppt", "pptx": return .orange
        case "html", "htm", "css": return .pink
        case "json", "yaml", "toml", "xml": return .yellow
        default: return .secondary
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 3) {
            primaryText
            if prefs.showTimestamps || prefs.showCharCount {
                metaRow
            }
        }
    }

    @ViewBuilder
    private var primaryText: some View {
        switch entry.type {
        case .text:
            if entry.isURL {
                let display =
                    entry.linkPreview?.title
                    ?? entry.linkPreview?.domain
                    ?? entry.text ?? ""
                Text(display)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            } else {
                let raw =
                    entry.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\t", with: " ") ?? ""
                let limit = prefs.rowDensity == .compact ? 80 : 150
                let preview = raw.count > limit ? String(raw.prefix(limit)) + "…" : raw
                Text(preview)
                    .font(.system(size: fontSize))
                    .lineLimit(prefs.rowDensity == .compact ? 1 : 2)
                    .foregroundStyle(.primary)
            }

        case .image:
            Text("Image")
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)

        case .file:
            Text(entry.fileName ?? "File")
                .font(.system(size: fontSize))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 5) {
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            }
            if prefs.showTimestamps {
                Text(timeAgo)
            }
            if let meta = metaLabel, prefs.showCharCount {
                Text("·")
                Text(meta)
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }

    private var metaLabel: String? {
        switch entry.type {
        case .text:
            if entry.isURL {
                return entry.linkPreview?.domain
            }
            let c = entry.text?.count ?? 0
            return "\(c) char\(c == 1 ? "" : "s")"
        case .image:
            return nil
        case .file:
            guard let url = entry.fileURL,
                let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            else { return entry.fileExtension }
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
    }

    // MARK: - Row Background

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : isHovered ? Color.primary.opacity(0.05) : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 3) {
            RowActionButton(
                icon: entry.isPinned ? "pin.slash.fill" : "pin.fill",
                tint: .orange,
                help: entry.isPinned ? "Unpin" : "Pin",
                action: onPin
            )
            RowActionButton(
                icon: "arrow.up.to.line",
                tint: .accentColor,
                help: "Paste",
                action: onPaste
            )
            RowActionButton(
                icon: "trash.fill",
                tint: .red,
                help: "Delete",
                action: onDelete
            )
        }
    }
}

// MARK: - Row Action Button

private struct RowActionButton: View {
    let icon: String
    let tint: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 10, weight: .medium))
        }
        .buttonStyle(PillButtonStyle(tint: tint))
        .help(help)
    }
}

private struct PillButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(configuration.isPressed ? 0.25 : 0.11))
            )
            .foregroundStyle(tint)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}
