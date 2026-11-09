import Cocoa

enum Pasteboard {
    /// Replaces the general pasteboard contents with a PNG image.
    static func copy(png: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
    }
}
