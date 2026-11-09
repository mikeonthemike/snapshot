import Testing
import Cocoa
@testable import Snapshot

@Suite struct TooltipPlacementTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 120, height: 24)

    @Test func goesBelowTheControlCentred() {
        let anchor = CGRect(x: 600, y: 500, width: 30, height: 28)
        let o = TooltipPlacement.origin(for: size, anchor: anchor, visible: screen)
        #expect(o.x == anchor.midX - size.width / 2)
        #expect(o.y == anchor.minY - TooltipPlacement.gap - size.height)
    }

    @Test func flipsAboveWhenThereIsNoRoomBelow() {
        let anchor = CGRect(x: 600, y: 10, width: 30, height: 28)
        let o = TooltipPlacement.origin(for: size, anchor: anchor, visible: screen)
        #expect(o.y == anchor.maxY + TooltipPlacement.gap)
    }

    @Test func staysInsideTheScreenHorizontally() {
        let left = TooltipPlacement.origin(for: size, anchor: CGRect(x: 0, y: 500, width: 30, height: 28), visible: screen)
        #expect(left.x == 4)
        let right = TooltipPlacement.origin(for: size, anchor: CGRect(x: 1420, y: 500, width: 30, height: 28), visible: screen)
        #expect(right.x == screen.maxX - size.width - 4)
    }

    @Test func staysInsideTheScreenVerticallyWhenFlippedAtTheTop() {
        // No room below, and above would run off the top: pinned to the top edge.
        let tall = CGRect(x: 600, y: 0, width: 30, height: 890)
        let o = TooltipPlacement.origin(for: size, anchor: tall, visible: screen)
        #expect(o.y + size.height <= screen.maxY - 4)
    }
}

@Suite(.serialized) @MainActor struct TooltipWindowTests {
    /// Native tooltips are drawn at level ~200, so ours must sit above even a shielding-level overlay.
    @Test func appearsAboveAnOwnerAtShieldingLevelAndHidesAgain() {
        _ = NSApplication.shared
        let owner = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 400, height: 300), styleMask: .borderless, backing: .buffered, defer: false)
        owner.isReleasedWhenClosed = false
        owner.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        owner.orderFront(nil)
        defer { owner.orderOut(nil) }

        TooltipWindow.shared.show("Copy (⌘C / Return)", near: CGRect(x: 200, y: 200, width: 30, height: 28), above: owner)
        let tip = owner.childWindows?.first
        #expect(tip != nil)
        #expect((tip?.level.rawValue ?? 0) > owner.level.rawValue)
        #expect(tip?.ignoresMouseEvents == true)

        TooltipWindow.shared.hide()
        #expect(owner.childWindows?.isEmpty ?? true)
    }
}
