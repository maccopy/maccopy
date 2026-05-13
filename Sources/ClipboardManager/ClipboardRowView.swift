import SwiftUI

struct ClipboardRowView: View {
    let entry: ClipboardEntry
    let onPaste: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var preview: String {
        let s = entry.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        return s.count > 140 ? String(s.prefix(140)) + "…" : s
    }

    private var timeAgo: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: entry.date, relativeTo: Date())
    }

    private var charCount: String {
        let c = entry.text.count
        return c == 1 ? "1 char" : "\(c) chars"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preview)
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(timeAgo)
                    Text("·")
                    Text(charCount)
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onPaste) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(ActionButtonStyle(tint: .accentColor))
                    .help("Paste (double-click)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(ActionButtonStyle(tint: .red))
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: onPaste)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(configuration.isPressed ? 0.25 : 0.12))
            )
            .foregroundStyle(tint)
    }
}
