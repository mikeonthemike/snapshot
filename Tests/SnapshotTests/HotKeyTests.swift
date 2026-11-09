import Testing
import Cocoa
import Carbon.HIToolbox
@testable import Snapshot

@Suite struct HotKeyTests {
    let optShiftA = HotKey(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey | shiftKey), key: "A")

    @Test func displayListsModifiersInMacOrder() {
        #expect(optShiftA.display == "⌥⇧A")
        let all = HotKey(keyCode: 0, modifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey), key: "K")
        #expect(all.display == "⌃⌥⇧⌘K")
    }

    @Test func menuKeyIsOnlyForSingleCharacterKeys() {
        #expect(optShiftA.menuKey == "a")
        #expect(HotKey(keyCode: 49, modifiers: UInt32(cmdKey), key: "Space").menuKey == "")
    }

    @Test func menuMaskMatchesModifiers() {
        #expect(optShiftA.menuMask == [.option, .shift])
    }

    @Test func carbonModifiersRoundTripThroughMenuMask() {
        let flags: NSEvent.ModifierFlags = [.control, .command]
        let carbon = HotKey.carbonModifiers(flags)
        #expect(carbon == UInt32(controlKey | cmdKey))
        let back = HotKey(keyCode: 0, modifiers: carbon, key: "X").menuMask
        #expect(back == flags)
    }

    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(optShiftA)
        #expect(try JSONDecoder().decode(HotKey.self, from: data) == optShiftA)
    }

    @Test func everyActionHasADistinctDefaultAndRawValue() {
        let fallbacks = HotKeyAction.allCases.map(\.fallback)
        for (i, a) in fallbacks.enumerated() {
            for b in fallbacks[(i + 1)...] { #expect(a != b) }
        }
        #expect(Set(HotKeyAction.allCases.map(\.rawValue)).count == HotKeyAction.allCases.count)
        #expect(Set(HotKeyAction.allCases.map(\.defaultsKey)).count == HotKeyAction.allCases.count)
    }

    @Test func defaultsAreOptionShiftAAndF() {
        #expect(HotKeyAction.capture.fallback.display == "⌥⇧A")
        #expect(HotKeyAction.fullScreen.fallback.display == "⌥⇧F")
    }
}
