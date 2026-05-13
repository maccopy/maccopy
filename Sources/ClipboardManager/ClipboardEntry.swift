import AppKit
import Foundation

enum ClipboardContentType: String, Codable {
    case text
    case image
    case file
}

struct ClipboardEntry: Identifiable, Equatable {
    let id: UUID
    let type: ClipboardContentType
    var text: String?
    var imageFileName: String?
    var fileURLString: String?
    var fileName: String?
    let date: Date
    var isPinned: Bool

    static func makeText(_ content: String) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(), type: .text, text: content, imageFileName: nil,
            fileURLString: nil, fileName: nil, date: Date(), isPinned: false)
    }

    static func makeImage(fileName: String) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(), type: .image, text: nil, imageFileName: fileName,
            fileURLString: nil, fileName: nil, date: Date(), isPinned: false)
    }

    static func makeFile(url: URL) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(), type: .file, text: nil, imageFileName: nil,
            fileURLString: url.absoluteString, fileName: url.lastPathComponent,
            date: Date(), isPinned: false)
    }

    var fileURL: URL? {
        fileURLString.flatMap { URL(string: $0) }
    }

    var searchableText: String {
        switch type {
        case .text: return text ?? ""
        case .image: return "image photo picture"
        case .file: return fileName ?? "file document"
        }
    }
}

extension ClipboardEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, type, text, imageFileName, fileURLString, fileName, date, isPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        type = (try c.decodeIfPresent(ClipboardContentType.self, forKey: .type)) ?? .text
        text = try c.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        fileURLString = try c.decodeIfPresent(String.self, forKey: .fileURLString)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        date = try c.decode(Date.self, forKey: .date)
        isPinned = (try c.decodeIfPresent(Bool.self, forKey: .isPinned)) ?? false
    }
}
