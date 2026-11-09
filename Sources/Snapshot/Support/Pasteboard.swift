import Cocoa

enum Pasteboard {
    /// Replaces the general pasteboard contents with a PNG image.
    static func copy(png: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(png, forType: .png)
    }

    /// Replaces the general pasteboard contents with plain text.
    static func copy(text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
