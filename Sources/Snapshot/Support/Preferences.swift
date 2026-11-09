import Foundation

/// Simple user preferences backed by `UserDefaults`.
enum Preferences {
    static let windowShadowKey = "windowShadow"
    static let saveOnCopyKey = "saveOnCopy"
    static let keepHistoryKey = "keepHistory"

    /// Whether the last few captures are remembered for the Recent Captures menu. On by default.
    static var keepHistory: Bool {
        get { UserDefaults.standard.object(forKey: keepHistoryKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: keepHistoryKey) }
    }

    /// Whether copying from the capture overlay also saves a file to the save folder. Off by default.
    static var saveOnCopy: Bool {
        get { UserDefaults.standard.object(forKey: saveOnCopyKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: saveOnCopyKey) }
    }

    /// Whether window screenshots keep the window's drop shadow. On by default.
    static var includeWindowShadow: Bool {
        get { UserDefaults.standard.object(forKey: windowShadowKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: windowShadowKey) }
    }
}
