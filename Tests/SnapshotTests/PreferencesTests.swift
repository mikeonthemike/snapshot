import Testing
import Foundation
@testable import Snapshot

@Suite(.serialized) struct PreferencesTests {
    @Test func windowShadowDefaultsToOnAndPersists() {
        let saved = UserDefaults.standard.object(forKey: Preferences.windowShadowKey)
        defer {
            if let saved = saved { UserDefaults.standard.set(saved, forKey: Preferences.windowShadowKey) }
            else { UserDefaults.standard.removeObject(forKey: Preferences.windowShadowKey) }
        }
        UserDefaults.standard.removeObject(forKey: Preferences.windowShadowKey)
        #expect(Preferences.includeWindowShadow == true)
        Preferences.includeWindowShadow = false
        #expect(Preferences.includeWindowShadow == false)
        Preferences.includeWindowShadow = true
        #expect(Preferences.includeWindowShadow == true)
    }

    @Test func saveOnCopyDefaultsToOffAndPersists() {
        let saved = UserDefaults.standard.object(forKey: Preferences.saveOnCopyKey)
        defer {
            if let saved = saved { UserDefaults.standard.set(saved, forKey: Preferences.saveOnCopyKey) }
            else { UserDefaults.standard.removeObject(forKey: Preferences.saveOnCopyKey) }
        }
        UserDefaults.standard.removeObject(forKey: Preferences.saveOnCopyKey)
        #expect(Preferences.saveOnCopy == false)
        Preferences.saveOnCopy = true
        #expect(Preferences.saveOnCopy == true)
        Preferences.saveOnCopy = false
        #expect(Preferences.saveOnCopy == false)
    }
}
