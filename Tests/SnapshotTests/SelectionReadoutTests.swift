import Testing
import CoreGraphics
@testable import Snapshot

@Suite struct SelectionReadoutTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let text = CGSize(width: 150, height: 14)

    @Test func showsSizeThenPosition() {
        #expect(SelectionReadout.text(for: CGRect(x: 120, y: 340, width: 800, height: 600)) == "800 × 600 at 120, 340")
    }

    @Test func dropsFractionsLikeTheSizeAlwaysDid() {
        #expect(SelectionReadout.text(for: CGRect(x: 10.7, y: 20.2, width: 99.9, height: 50.5)) == "99 × 50 at 10, 20")
    }

    @Test func positionIsRelativeToTheDisplayOrigin() {
        #expect(SelectionReadout.text(for: CGRect(x: 0, y: 0, width: 5, height: 5)) == "5 × 5 at 0, 0")
    }

    @Test func pillSitsAboveTheTopLeftCorner() {
        let s = CGRect(x: 300, y: 300, width: 200, height: 100)
        let f = SelectionReadout.pillFrame(textSize: text, selection: s, bounds: bounds)
        #expect(f.minX == 300)
        #expect(f.maxY < 300)
        #expect(f.size == CGSize(width: text.width + 12, height: text.height + 4))
    }

    @Test func pillStaysOnScreenAtTheRightEdge() {
        let s = CGRect(x: 1400, y: 300, width: 40, height: 100)
        let f = SelectionReadout.pillFrame(textSize: text, selection: s, bounds: bounds)
        #expect(f.maxX <= bounds.maxX - 4)
    }

    @Test func pillStaysOnScreenAtTheTop() {
        let s = CGRect(x: 300, y: 0, width: 200, height: 100)
        let f = SelectionReadout.pillFrame(textSize: text, selection: s, bounds: bounds)
        #expect(f.minY >= 4)
    }
}
