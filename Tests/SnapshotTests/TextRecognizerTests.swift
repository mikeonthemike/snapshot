import Testing
import Cocoa
@testable import Snapshot

@Suite struct TextRecognizerTests {
    /// Renders black text on white, the way a screenshot of a document would look.
    private func image(of lines: [String]) -> CGImage {
        let w = 900, h = 120 * lines.count + 40
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        for (i, line) in lines.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black]
            NSAttributedString(string: line, attributes: attrs).draw(at: CGPoint(x: 30, y: h - 110 - i * 120))
        }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }

    @Test func recognisesRenderedText() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: ["Hello Snapshot"]))
        #expect(text.contains("Hello"))
        #expect(text.contains("Snapshot"))
    }

    @Test func keepsLinesInReadingOrder() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: ["First line", "Second line"]))
        let first = try #require(text.range(of: "First"))
        let second = try #require(text.range(of: "Second"))
        #expect(first.lowerBound < second.lowerBound)
    }

    @Test func blankImageGivesEmptyText() async throws {
        let text = try await TextRecognizer.recognize(in: image(of: [""]))
        #expect(text.isEmpty)
    }
}
