import Cocoa

enum ScreenCapturePermission {
    /// Returns true if Screen Recording access is granted. Otherwise prompts the user and returns false.
    static func ensure() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Snapshot needs Screen Recording access"
        alert.informativeText = "Enable Snapshot in System Settings → Privacy & Security → Screen Recording, then quit and reopen Snapshot."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        return false
    }
}
