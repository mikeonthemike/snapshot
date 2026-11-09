import Foundation

/// Simple user preferences backed by `UserDefaults`.
enum Preferences {
    static let windowShadowKey = "windowShadow"

    /// Whether window screenshots keep the window's drop shadow. On by default.
    static var includeWindowShadow: Bool {
        get { UserDefaults.standard.object(forKey: windowShadowKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: windowShadowKey) }
    }
}
