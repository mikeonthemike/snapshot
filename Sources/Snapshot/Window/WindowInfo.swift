import Cocoa

/// A visible application window, as reported by the window server.
struct WindowInfo: Equatable {
    let id: CGWindowID
    /// Global display coordinates, top-left origin (Quartz).
    let bounds: CGRect
    let owner: String
    let title: String

    /// "App — Window title", or just the app name.
    var label: String { title.isEmpty ? owner : "\(owner) — \(title)" }

    /// `bounds` relative to a display's own top-left corner.
    func localBounds(onDisplay display: CGRect) -> CGRect {
        bounds.offsetBy(dx: -display.minX, dy: -display.minY)
    }
}

enum WindowList {
    /// Smallest window worth offering, in points. Filters out invisible helper windows.
    static let minimumSize: CGFloat = 40

    /// On-screen application windows, front to back, excluding this app's own.
    static func current(excludingPID pid: pid_t = getpid()) -> [WindowInfo] {
        let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        return parse(raw ?? [], excludingPID: pid)
    }

    /// Turns window-server dictionaries into `WindowInfo`, keeping only ordinary visible windows.
    static func parse(_ infos: [[String: Any]], excludingPID pid: pid_t) -> [WindowInfo] {
        infos.compactMap { d in
            guard (d[kCGWindowLayer as String] as? Int) == 0,                       // normal windows, not menu bar/Dock
                  (d[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  (d[kCGWindowOwnerPID as String] as? Int32) != pid,
                  let id = d[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = d[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= minimumSize, bounds.height >= minimumSize
            else { return nil }
            return WindowInfo(id: id, bounds: bounds,
                              owner: d[kCGWindowOwnerName as String] as? String ?? "",
                              title: d[kCGWindowName as String] as? String ?? "")
        }
    }

    /// The frontmost window containing `point` (global display coordinates). `windows` must be front to back.
    static func topmost(at point: CGPoint, in windows: [WindowInfo]) -> WindowInfo? {
        windows.first { $0.bounds.contains(point) }
    }
}
