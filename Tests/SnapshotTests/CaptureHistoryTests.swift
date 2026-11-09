import Testing
import Cocoa
@testable import Snapshot

/// A solid-colour PNG of the given pixel size.
private func png(width: Int = 60, height: Int = 40, color: NSColor = .red) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(color.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

private func tempHistory(limit: Int = 5) -> (CaptureHistory, URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-history-\(UUID().uuidString)", isDirectory: true)
    return (CaptureHistory(directory: dir, limit: limit), dir)
}

@Suite struct CaptureHistoryTests {
    @Test func startsEmptyEvenIfTheFolderDoesNotExist() {
        let (h, _) = tempHistory()
        #expect(h.entries.isEmpty)
    }

    @Test func addedCapturesComeBackNewestFirst() {
        let (h, dir) = tempHistory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let t = Date()
        let a = h.add(png: png(), date: t)
        let b = h.add(png: png(), date: t.addingTimeInterval(10))
        let c = h.add(png: png(), date: t.addingTimeInterval(20))
        #expect(h.entries.map(\.url.lastPathComponent) == [c, b, a].compactMap { $0?.url.lastPathComponent })
    }

    @Test func keepsOnlyTheNewestUpToTheLimit() {
        let (h, dir) = tempHistory(limit: 3)
        defer { try? FileManager.default.removeItem(at: dir) }
        let t = Date()
        for i in 0..<5 { h.add(png: png(), date: t.addingTimeInterval(Double(i))) }
        let entries = h.entries
        #expect(entries.count == 3)
        // The three newest survive, in order (allowing for the millisecond rounding in the file name).
        let expected = [4.0, 3, 2].map { t.addingTimeInterval($0).timeIntervalSince1970 }
        for (entry, want) in zip(entries, expected) { #expect(abs(entry.date.timeIntervalSince1970 - want) < 0.001) }
        // The evicted files are really gone, not just hidden.
        #expect((try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.count == 3)
    }

    @Test func removeAndClearDeleteFiles() {
        let (h, dir) = tempHistory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = h.add(png: png(), date: Date())!
        h.add(png: png(), date: Date().addingTimeInterval(1))
        h.remove(a.url)
        #expect(h.entries.count == 1)
        h.clear()
        #expect(h.entries.isEmpty)
        #expect((try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.isEmpty == true)
    }

    @Test func ignoresFilesThatAreNotHistoryEntries() throws {
        let (h, dir) = tempHistory()
        defer { try? FileManager.default.removeItem(at: dir) }
        h.add(png: png())
        try Data("hi".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        try Data("hi".utf8).write(to: dir.appendingPathComponent("abc-def.png"))
        #expect(h.entries.count == 1)
    }

    @Test func survivesBeingReopened() {
        let (h, dir) = tempHistory()
        defer { try? FileManager.default.removeItem(at: dir) }
        h.add(png: png())
        #expect(CaptureHistory(directory: dir, limit: 5).entries.count == 1)
    }

    @Test func historyFolderIsPrivate() throws {
        let (h, dir) = tempHistory()
        defer { try? FileManager.default.removeItem(at: dir) }
        h.add(png: png())
        let perms = try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int
        #expect(perms == 0o700)
    }

    @Test func fileNamesSortByTimeAndNeverCollide() {
        let t = Date()
        let a = CaptureHistory.fileName(for: t), b = CaptureHistory.fileName(for: t)
        #expect(a != b)
        #expect(CaptureHistory.fileName(for: t) < CaptureHistory.fileName(for: t.addingTimeInterval(1)))
    }

    @Test func fileNameRoundTripsTheDate() throws {
        let t = Date()
        let entry = try #require(CaptureHistory.entry(for: URL(fileURLWithPath: "/x/" + CaptureHistory.fileName(for: t))))
        #expect(abs(entry.date.timeIntervalSince(t)) < 0.001)
    }

    @Test func defaultsToFiveAndLivesInApplicationSupport() {
        #expect(CaptureHistory.defaultLimit == 5)
        #expect(CaptureHistory.defaultDirectory.path.contains("Application Support/Snapshot/History"))
    }

    @Test func pixelSizeAndThumbnailComeFromTheFile() throws {
        let (h, dir) = tempHistory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let e = try #require(h.add(png: png(width: 400, height: 200)))
        #expect(CaptureHistory.pixelSize(of: e.url) == CGSize(width: 400, height: 200))
        let thumb = try #require(CaptureHistory.thumbnail(for: e.url, maxPixelSize: 100))
        #expect(max(thumb.size.width, thumb.size.height) <= 100)
        #expect(thumb.size.width > thumb.size.height)   // aspect preserved
    }
}

@Suite struct PinPlacementTests {
    private let screen = CGSize(width: 1000, height: 800)

    @Test func smallImagesKeepTheirNaturalSize() {
        #expect(PinPlacement.fittedSize(CGSize(width: 300, height: 200), in: screen) == CGSize(width: 300, height: 200))
    }

    @Test func largeImagesShrinkToFitKeepingAspect() {
        let s = PinPlacement.fittedSize(CGSize(width: 2000, height: 1000), in: screen)
        #expect(s.width == 700)                 // 70% of the screen width
        #expect(s.height == 350)
    }
}

@Suite struct ImageEncodingTests {
    /// Pinning builds a point-sized NSImage around a larger Retina bitmap; history must keep every pixel.
    @Test func pngDataKeepsTheRetinaPixelsOfAPinnedImage() throws {
        let ctx = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.blue.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        let image = NSImage(size: NSSize(width: 100, height: 50))   // 2x
        image.addRepresentation(rep)

        let data = try #require(image.pngData)
        let back = try #require(NSBitmapImageRep(data: data))
        #expect(back.pixelsWide == 200 && back.pixelsHigh == 100)
    }
}
