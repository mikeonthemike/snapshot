import Testing
import Cocoa
@testable import Snapshot

@Suite struct WindowListTests {
    private func entry(id: CGWindowID, _ bounds: CGRect, layer: Int = 0, alpha: Double = 1, pid: Int32 = 100,
                       owner: String = "Safari", title: String = "Apple") -> [String: Any] {
        [
            kCGWindowNumber as String: id,
            kCGWindowBounds as String: bounds.dictionaryRepresentation as NSDictionary,
            kCGWindowLayer as String: layer,
            kCGWindowAlpha as String: alpha,
            kCGWindowOwnerPID as String: pid,
            kCGWindowOwnerName as String: owner,
            kCGWindowName as String: title,
        ]
    }

    private let big = CGRect(x: 0, y: 0, width: 800, height: 600)

    @Test func parsesOrdinaryWindows() {
        let list = WindowList.parse([entry(id: 7, big)], excludingPID: 1)
        #expect(list == [WindowInfo(id: 7, bounds: big, owner: "Safari", title: "Apple")])
    }

    @Test func dropsMenuBarDockOwnHiddenAndTinyWindows() {
        let list = WindowList.parse([
            entry(id: 1, big, layer: 24),              // menu bar level
            entry(id: 2, big, layer: 20),              // Dock level
            entry(id: 3, big, alpha: 0),               // invisible
            entry(id: 4, big, pid: 42),                // our own process
            entry(id: 5, CGRect(x: 0, y: 0, width: 10, height: 10)), // helper sliver
            entry(id: 6, big),
        ], excludingPID: 42)
        #expect(list.map(\.id) == [6])
    }

    @Test func missingNamesBecomeEmptyStrings() {
        var e = entry(id: 9, big)
        e[kCGWindowName as String] = nil
        e[kCGWindowOwnerName as String] = nil
        let w = WindowList.parse([e], excludingPID: 1)[0]
        #expect(w.owner == "" && w.title == "")
    }

    @Test func labelCombinesAppAndTitle() {
        #expect(WindowInfo(id: 1, bounds: big, owner: "Safari", title: "Apple").label == "Safari — Apple")
        #expect(WindowInfo(id: 1, bounds: big, owner: "Finder", title: "").label == "Finder")
    }

    @Test func topmostPicksTheFrontWindowUnderThePoint() {
        let front = WindowInfo(id: 1, bounds: CGRect(x: 100, y: 100, width: 300, height: 300), owner: "A", title: "")
        let back = WindowInfo(id: 2, bounds: CGRect(x: 0, y: 0, width: 800, height: 600), owner: "B", title: "")
        let list = [front, back]   // front to back
        #expect(WindowList.topmost(at: CGPoint(x: 150, y: 150), in: list)?.id == 1)
        #expect(WindowList.topmost(at: CGPoint(x: 600, y: 500), in: list)?.id == 2)
        #expect(WindowList.topmost(at: CGPoint(x: 900, y: 900), in: list) == nil)
    }

    @Test func localBoundsAreRelativeToTheDisplay() {
        let w = WindowInfo(id: 1, bounds: CGRect(x: 1500, y: -200, width: 400, height: 300), owner: "A", title: "")
        // A second display sitting to the right of and above the main one.
        let display = CGRect(x: 1440, y: -300, width: 1920, height: 1080)
        #expect(w.localBounds(onDisplay: display) == CGRect(x: 60, y: 100, width: 400, height: 300))
    }

    @Test func liveWindowListIsSane() {
        for w in WindowList.current() {
            #expect(w.bounds.width >= WindowList.minimumSize && w.bounds.height >= WindowList.minimumSize)
        }
    }
}
