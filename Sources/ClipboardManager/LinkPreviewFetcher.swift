import AppKit
import Foundation

struct LinkPreview: Codable, Equatable {
    var title: String?
    var domain: String
    var faviconURL: String?
}

actor LinkPreviewFetcher {
    static let shared = LinkPreviewFetcher()

    private var cache: [String: LinkPreview] = [:]
    private var inFlight: [String: Task<LinkPreview?, Never>] = [:]

    func fetch(urlString: String) async -> LinkPreview? {
        if let cached = cache[urlString] { return cached }

        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<LinkPreview?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.perform(urlString: urlString)
        }
        inFlight[urlString] = task
        let result = await task.value
        inFlight.removeValue(forKey: urlString)
        if let result { cache[urlString] = result }
        return result
    }

    private func perform(urlString: String) async -> LinkPreview? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=32"
        var preview = LinkPreview(title: nil, domain: domain, faviconURL: faviconURL)
        preview.title = await fetchTitle(url: url)
        return preview
    }

    private func fetchTitle(url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else { return nil }

        return extractOGTitle(html: html) ?? extractTitle(html: html)
    }

    private func extractOGTitle(html: String) -> String? {
        let patterns = [
            #"property="og:title"\s+content="([^"]+)""#,
            #"content="([^"]+)"\s+property="og:title""#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                let match = regex.firstMatch(
                    in: html, range: NSRange(html.startIndex..., in: html)),
                let range = Range(match.range(at: 1), in: html)
            {
                return String(html[range]).htmlDecoded.trimmed
            }
        }
        return nil
    }

    private func extractTitle(html: String) -> String? {
        guard
            let regex = try? NSRegularExpression(
                pattern: #"<title[^>]*>([^<]+)</title>"#, options: .caseInsensitive),
            let match = regex.firstMatch(
                in: html, range: NSRange(html.startIndex..., in: html)),
            let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[range]).htmlDecoded.trimmed
    }
}

func loadFaviconImage(from urlString: String) async -> NSImage? {
    guard let url = URL(string: urlString),
        let (data, _) = try? await URLSession.shared.data(from: url)
    else { return nil }
    return NSImage(data: data)
}

private extension String {
    var htmlDecoded: String {
        var s = self
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " "),
        ]
        for (entity, char) in entities { s = s.replacingOccurrences(of: entity, with: char) }
        return s
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
