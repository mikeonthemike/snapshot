import Cocoa

/// Grabs the current screen contents by running `/usr/sbin/screencapture`.
enum ScreenGrabber {
    /// A still of one display (1-based, in `screencapture -D` order).
    static func image(ofDisplay displayIndex: Int) -> NSImage? {
        guard let path = run(["-D", "\(displayIndex)"]) else { return nil }
        defer { try? FileManager.default.removeItem(atPath: path) }
        return NSImage(contentsOfFile: path)
    }

    /// PNG data for the main display.
    static func mainDisplayPNG() -> Data? {
        guard let path = run([]) else { return nil }
        defer { try? FileManager.default.removeItem(atPath: path) }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    /// Runs `screencapture -x <args> <temp file>` and returns the temp file path on launch success.
    private static func run(_ args: [String]) -> String? {
        let path = NSTemporaryDirectory() + "snapshot-\(UUID().uuidString).png"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-x"] + args + [path]
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        return path
    }
}
