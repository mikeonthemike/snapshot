import Cocoa

/// What the capture overlay asks of the rest of the app. `CaptureView` only draws, edits and renders;
/// everything with a side effect outside the overlay (clipboard, disk, pins, recording) goes through here.
protocol CaptureViewDelegate: AnyObject {
    /// The user dismissed the overlay.
    func captureViewDidCancel(_ view: CaptureView)
    func captureView(_ view: CaptureView, didCopy png: Data)
    func captureView(_ view: CaptureView, didSave png: Data)
    /// Recognise text in the selected region and copy it.
    func captureView(_ view: CaptureView, didRequestTextFrom image: CGImage)
    /// `frame` is in global AppKit screen coordinates.
    func captureView(_ view: CaptureView, didPin image: NSImage, at frame: NSRect)
    /// `rect` is in display points, top-left origin; `scale` is pixels per point.
    func captureView(_ view: CaptureView, didRequestRecordingOn displayID: CGDirectDisplayID, rect: CGRect, scale: CGFloat)
}
