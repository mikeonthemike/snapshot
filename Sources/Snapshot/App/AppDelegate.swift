import Cocoa

/// Wires the pieces together at launch. Behaviour lives in the feature types it connects.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        Recorder.shared.onChange = { [weak self] in self?.menuBar.recordingChanged() }

        HotKeys.shared.onAction = Self.handle
        HotKeys.shared.onChange = { [weak self] in self?.menuBar.applyHotkeys() }
        HotKeys.shared.install()
        menuBar.applyHotkeys()
    }

    private static func handle(_ action: HotKeyAction) {
        switch action {
        case .capture:
            if Recorder.shared.isRecording { Recorder.shared.stop() } else { CaptureController.shared.begin() }
        case .fullScreen:
            if !Recorder.shared.isRecording { CaptureController.shared.fullScreen() }
        }
    }
}
