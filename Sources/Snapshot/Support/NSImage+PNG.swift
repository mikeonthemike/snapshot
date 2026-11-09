import Cocoa

extension NSImage {
    /// PNG data for the image's best representation, or nil if it can't be encoded.
    var pngData: Data? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }
}
