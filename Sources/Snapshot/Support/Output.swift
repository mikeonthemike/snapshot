import Cocoa

enum Output {
    static let defaultsKey = "saveFolderPath"

    static var defaultFolder: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// The user's chosen save folder, falling back to the Desktop if it is unset or has gone missing.
    static var folder: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: defaultsKey) {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    return URL(fileURLWithPath: path, isDirectory: true)
                }
            }
            return defaultFolder
        }
        set {
            if newValue.standardizedFileURL == defaultFolder.standardizedFileURL {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            } else {
                UserDefaults.standard.set(newValue.path, forKey: defaultsKey)
            }
        }
    }

    static func newURL(prefix: String, ext: String) -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return folder.appendingPathComponent("\(prefix) \(f.string(from: Date())).\(ext)")
    }

    @discardableResult
    static func save(png: Data) -> URL? {
        let url = newURL(prefix: "Snapshot", ext: "png")
        do { try png.write(to: url); return url } catch { NSSound.beep(); return nil }
    }
}
