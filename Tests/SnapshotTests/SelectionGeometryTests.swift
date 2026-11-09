import Testing
import Cocoa
@testable import Snapshot

@Suite struct SelectionGeometryTests {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let selection = CGRect(x: 100, y: 100, width: 200, height: 100)

    @Test func spanningNormalisesCorners() {
        let r = CGRect.spanning(CGPoint(x: 50, y: 40), CGPoint(x: 10, y: 90))
        #expect(r == CGRect(x: 10, y: 40, width: 40, height: 50))
    }

    @Test func handleRectsSitOnTheEdgesAndMidpoints() {
        let tl = SelectionGeometry.handleRect(.topLeft, in: selection)
        #expect(tl.midX == 100 && tl.midY == 100)
        let br = SelectionGeometry.handleRect(.bottomRight, in: selection)
        #expect(br.midX == 300 && br.midY == 200)
        let top = SelectionGeometry.handleRect(.top, in: selection)
        #expect(top.midX == 200 && top.midY == 100)
        #expect(top.size == CGSize(width: SelectionGeometry.handleSize, height: SelectionGeometry.handleSize))
    }

    @Test func hitTestFindsHandlesWithSlopAndNothingElsewhere() {
        #expect(SelectionGeometry.handle(at: CGPoint(x: 100, y: 100), in: selection) == .topLeft)
        // Just outside the 10pt handle but inside the 3pt slop.
        #expect(SelectionGeometry.handle(at: CGPoint(x: 107, y: 100), in: selection) == .topLeft)
        #expect(SelectionGeometry.handle(at: CGPoint(x: 200, y: 150), in: selection) == nil)
        #expect(SelectionGeometry.handle(at: CGPoint(x: 300, y: 150), in: selection) == .right)
    }

    @Test func resizingFromACornerMovesOnlyThoseEdges() {
        let r = SelectionGeometry.resized(selection, dragging: .bottomRight, to: CGPoint(x: 400, y: 300), within: bounds)
        #expect(r == CGRect(x: 100, y: 100, width: 300, height: 200))
    }

    @Test func resizingFromAnEdgeKeepsTheOtherAxis() {
        let r = SelectionGeometry.resized(selection, dragging: .right, to: CGPoint(x: 500, y: 9999), within: bounds)
        #expect(r == CGRect(x: 100, y: 100, width: 400, height: 100))
    }

    @Test func resizingPastTheOppositeEdgeFlipsTheRect() {
        let r = SelectionGeometry.resized(selection, dragging: .left, to: CGPoint(x: 400, y: 0), within: bounds)
        #expect(r == CGRect(x: 300, y: 100, width: 100, height: 100))
    }

    @Test func resizingIsClampedToBounds() {
        let r = SelectionGeometry.resized(selection, dragging: .topLeft, to: CGPoint(x: -50, y: -50), within: bounds)
        #expect(r == CGRect(x: 0, y: 0, width: 300, height: 200))
    }

    @Test func movingAppliesTheDelta() {
        let r = SelectionGeometry.moved(selection, by: CGPoint(x: 30, y: -20), within: bounds)
        #expect(r == CGRect(x: 130, y: 80, width: 200, height: 100))
    }

    @Test func movingStopsAtEveryEdge() {
        #expect(SelectionGeometry.moved(selection, by: CGPoint(x: -500, y: -500), within: bounds).origin == .zero)
        let far = SelectionGeometry.moved(selection, by: CGPoint(x: 5000, y: 5000), within: bounds)
        #expect(far.maxX == bounds.maxX && far.maxY == bounds.maxY)
        #expect(far.size == selection.size)
    }

    @Test func toolbarSitsBelowTheSelectionRightAligned() {
        let size = CGSize(width: 300, height: 40)
        let wide = CGRect(x: 100, y: 100, width: 500, height: 100)
        let o = SelectionGeometry.toolbarOrigin(size: size, selection: wide, bounds: bounds)
        #expect(o == CGPoint(x: wide.maxX - size.width, y: wide.maxY + 8))
    }

    @Test func toolbarMovesAboveWhenThereIsNoRoomBelow() {
        let low = CGRect(x: 100, y: 600, width: 200, height: 190)
        let size = CGSize(width: 300, height: 40)
        let o = SelectionGeometry.toolbarOrigin(size: size, selection: low, bounds: bounds)
        #expect(o.y == low.minY - size.height - 30)
    }

    @Test func toolbarMovesInsideWhenThereIsNoRoomAboveOrBelow() {
        let tall = CGRect(x: 100, y: 10, width: 200, height: 780)
        let size = CGSize(width: 300, height: 40)
        let o = SelectionGeometry.toolbarOrigin(size: size, selection: tall, bounds: bounds)
        #expect(o.y == tall.maxY - size.height - 8)
    }

    @Test func toolbarStaysOnScreenHorizontally() {
        let size = CGSize(width: 300, height: 40)
        let left = SelectionGeometry.toolbarOrigin(size: size, selection: CGRect(x: 0, y: 100, width: 50, height: 50), bounds: bounds)
        #expect(left.x == 8)
        let right = SelectionGeometry.toolbarOrigin(size: size, selection: CGRect(x: 960, y: 100, width: 40, height: 50), bounds: bounds)
        #expect(right.x <= bounds.maxX - size.width - 8)
    }
}
