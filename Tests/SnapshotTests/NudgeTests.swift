import Testing
import Cocoa
@testable import Snapshot

@Suite struct ArrowKeyTests {
    @Test func mapsTheFourArrowKeyCodes() {
        #expect(ArrowKey(keyCode: 123) == .left)
        #expect(ArrowKey(keyCode: 124) == .right)
        #expect(ArrowKey(keyCode: 125) == .down)
        #expect(ArrowKey(keyCode: 126) == .up)
        #expect(ArrowKey(keyCode: 0) == nil)
        #expect(ArrowKey(keyCode: 36) == nil)   // Return
    }

    @Test func upIsNegativeYBecauseTheViewIsFlipped() {
        #expect(ArrowKey.up.vector == CGPoint(x: 0, y: -1))
        #expect(ArrowKey.down.vector == CGPoint(x: 0, y: 1))
        #expect(ArrowKey.left.vector == CGPoint(x: -1, y: 0))
        #expect(ArrowKey.right.vector == CGPoint(x: 1, y: 0))
    }
}

@Suite struct KeyboardResizeGeometryTests {
    private let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let s = CGRect(x: 100, y: 100, width: 200, height: 100)

    @Test func growsAndShrinksKeepingTheTopLeftFixed() {
        #expect(SelectionGeometry.resized(s, byWidth: 10, height: 0, within: bounds) == CGRect(x: 100, y: 100, width: 210, height: 100))
        #expect(SelectionGeometry.resized(s, byWidth: 0, height: -10, within: bounds) == CGRect(x: 100, y: 100, width: 200, height: 90))
    }

    @Test func neverShrinksBelowTheMinimum() {
        let r = SelectionGeometry.resized(CGRect(x: 0, y: 0, width: 10, height: 10), byWidth: -100, height: -100, within: bounds)
        #expect(r.width == SelectionGeometry.minimumSize && r.height == SelectionGeometry.minimumSize)
    }

    @Test func neverGrowsPastTheScreenEdge() {
        let r = SelectionGeometry.resized(CGRect(x: 900, y: 700, width: 90, height: 90), byWidth: 50, height: 50, within: bounds)
        #expect(r.maxX == bounds.maxX && r.maxY == bounds.maxY)
    }
}

@Suite @MainActor struct CaptureViewNudgeTests {
    private func makeView() -> CaptureView {
        let view = CaptureView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), image: NSImage(size: NSSize(width: 800, height: 600)), scale: 2)
        view.selection = CGRect(x: 100, y: 100, width: 200, height: 100)
        view.annotations = [Annotation(tool: .rect, points: [CGPoint(x: 120, y: 120), CGPoint(x: 180, y: 160)], color: .red)]
        return view
    }

    private func press(_ keyCode: UInt16, _ flags: NSEvent.ModifierFlags = [], on view: CaptureView) {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                                     context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode)!
        view.keyDown(with: event)
    }

    @Test func arrowMovesTheSelectionOnePoint() {
        let v = makeView()
        press(124, on: v)   // right
        #expect(v.selection == CGRect(x: 101, y: 100, width: 200, height: 100))
        press(126, on: v)   // up
        #expect(v.selection == CGRect(x: 101, y: 99, width: 200, height: 100))
    }

    @Test func shiftMovesTenPoints() {
        let v = makeView()
        press(125, .shift, on: v)   // down
        #expect(v.selection?.origin == CGPoint(x: 100, y: 110))
    }

    @Test func annotationsTravelWithTheSelection() {
        let v = makeView()
        press(124, .shift, on: v)
        #expect(v.annotations[0].points == [CGPoint(x: 130, y: 120), CGPoint(x: 190, y: 160)])
    }

    @Test func optionArrowsResizeInsteadOfMoving() {
        let v = makeView()
        press(124, .option, on: v)             // wider
        press(125, [.option, .shift], on: v)   // 10 taller
        #expect(v.selection == CGRect(x: 100, y: 100, width: 201, height: 110))
        // Annotations stay put when only the size changes.
        #expect(v.annotations[0].points.first == CGPoint(x: 120, y: 120))
    }

    @Test func movingStopsAtTheEdgeOfTheScreen() {
        let v = makeView()
        v.selection = CGRect(x: 1, y: 1, width: 200, height: 100)
        press(123, .shift, on: v)   // left by 10, but only 1 point of room
        press(126, .shift, on: v)
        #expect(v.selection?.origin == .zero)
    }

    @Test func doesNothingWithoutASelectionOrWithCommandHeld() {
        let v = makeView()
        v.selection = nil
        press(124, on: v)
        #expect(v.selection == nil)

        let w = makeView()
        press(124, .command, on: w)
        #expect(w.selection == CGRect(x: 100, y: 100, width: 200, height: 100))
    }

    @Test func ignoredWhileDraggingOutANewSelection() {
        let v = makeView()
        v.dragStart = CGPoint(x: 50, y: 50)
        press(124, on: v)
        #expect(v.selection == CGRect(x: 100, y: 100, width: 200, height: 100))
    }
}
