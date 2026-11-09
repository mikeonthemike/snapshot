import Cocoa
import ImageIO

/// One remembered capture.
struct HistoryEntry: Equatable {
    let url: URL
    let date: Date
}

/// The last few captures, kept as PNG files in a private folder so they're available even if the capture was only
/// copied. Newest first, capped at `limit`; older ones are deleted as new ones arrive.
final class CaptureHistory {
    /// How many captures to remember (and show in the menu).
    static let defaultLimit = 5

    static let shared = CaptureHistory(directory: defaultDirectory, limit: defaultLimit)

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Snapshot", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
    }

    let directory: URL
    let limit: Int

    init(directory: URL, limit: Int) {
        self.directory = directory
        self.limit = limit
    }

    /// Remembers `png` unless history is switched off in Settings.
    static func record(_ png: Data) {
        guard Preferences.keepHistory else { return }
        shared.add(png: png)
    }

    /// Newest first.
    var entries: [HistoryEntry] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.compactMap(Self.entry(for:)).sorted { $0.date > $1.date }
    }

    @discardableResult
    func add(png: Data, date: Date = Date()) -> HistoryEntry? {
        do {
            // Private to this user: screenshots can contain anything.
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            let url = directory.appendingPathComponent(Self.fileName(for: date))
            try png.write(to: url)
            trim()
            return Self.entry(for: url)
        } catch {
            return nil
        }
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func clear() {
        entries.forEach { remove($0.url) }
    }

    private func trim() {
        entries.dropFirst(limit).forEach { remove($0.url) }
    }

    // MARK: File names

    /// `<milliseconds since 1970, zero padded>-<uuid>.png`, so names sort by time and never collide.
    static func fileName(for date: Date) -> String {
        let ms = Int((date.timeIntervalSince1970 * 1000).rounded())
        return String(format: "%014ld", ms) + "-\(UUID().uuidString).png"
    }

    static func entry(for url: URL) -> HistoryEntry? {
        guard url.pathExtension == "png",
              let prefix = url.lastPathComponent.split(separator: "-").first,
              let ms = Int(prefix) else { return nil }
        return HistoryEntry(url: url, date: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
    }

    // MARK: Images

    /// A small thumbnail whose longest side is at most `maxPixelSize` pixels.
    static func thumbnail(for url: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    /// The image's size in pixels, without decoding it.
    static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: w, height: h)
    }
}
