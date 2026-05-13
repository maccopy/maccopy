import SwiftUI

struct ClipboardRowView: View {
    let entry: ClipboardEntry
    let isSelected: Bool
    let onPaste: () -> Void
    let onDelete: () -> Void
    let onPin: () -> Void

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    private var timeAgo: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: entry.date, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            typeIndicator
            contentArea
            Spacer(minLength: 4)
            if isHovered || isSelected {
                actionButtons
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onPaste)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .task(id: entry.id) {
            if entry.type == .image {
                thumbnailImage = ClipboardStore.shared.loadImage(for: entry)
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var typeIndicator: some View {
        switch entry.type {
        case .text:
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(width: 28)

        case .image:
            Group {
                if let img = thumbnailImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .file:
            Image(systemName: "doc.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 28)
        }
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            primaryText
            HStack(spacing: 5) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
                Text(timeAgo)
                if let meta = metaLabel {
                    Text("·")
                    Text(meta)
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var primaryText: some View {
        switch entry.type {
        case .text:
            let raw =
                entry.text?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ") ?? ""
            let preview = raw.count > 150 ? String(raw.prefix(150)) + "…" : raw
            Text(preview)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.primary)

        case .image:
            Text("Image")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

        case .file:
            Text(entry.fileName ?? "File")
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }

    private var metaLabel: String? {
        switch entry.type {
        case .text:
            let c = entry.text?.count ?? 0
            return "\(c) char\(c == 1 ? "" : "s")"
        case .image:
            return nil
        case .file:
            guard let url = entry.fileURL,
                let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            else { return nil }
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.14)
                    : isHovered ? Color.primary.opacity(0.06) : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            RowActionButton(
                icon: entry.isPinned ? "pin.slash" : "pin",
                tint: .orange,
                help: entry.isPinned ? "Unpin" : "Pin",
                action: onPin
            )
            RowActionButton(
                icon: "doc.on.clipboard", tint: .accentColor, help: "Paste", action: onPaste)
            RowActionButton(icon: "trash", tint: .red, help: "Delete", action: onDelete)
        }
    }
}

private struct RowActionButton: View {
    let icon: String
    let tint: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11))
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
                    .fill(tint.opacity(configuration.isPressed ? 0.28 : 0.13))
            )
            .foregroundStyle(tint)
    }
}
