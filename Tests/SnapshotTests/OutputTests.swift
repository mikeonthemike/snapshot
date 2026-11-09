import Testing
import Foundation
@testable import Snapshot

/// `Output.folder` is backed by `UserDefaults.standard`, so these run serially and restore whatever was there.
@Suite(.serialized) struct OutputTests {
    private func withSavedFolder<T>(_ body: () throws -> T) rethrows -> T {
        let saved = UserDefaults.standard.string(forKey: Output.defaultsKey)
        defer {
            if let saved = saved { UserDefaults.standard.set(saved, forKey: Output.defaultsKey) }
            else { UserDefaults.standard.removeObject(forKey: Output.defaultsKey) }
        }
        return try body()
    }

    @Test func unsetFolderFallsBackToDesktop() {
        withSavedFolder {
            UserDefaults.standard.removeObject(forKey: Output.defaultsKey)
            #expect(Output.folder == Output.defaultFolder)
        }
    }

    @Test func missingFolderFallsBackToDesktop() {
        withSavedFolder {
            UserDefaults.standard.set("/definitely/not/a/real/folder", forKey: Output.defaultsKey)
            #expect(Output.folder == Output.defaultFolder)
        }
    }

    @Test func chosenFolderIsUsedAndDefaultIsNotPersisted() {
        withSavedFolder {
            let tmp = FileManager.default.temporaryDirectory
            Output.folder = tmp
            #expect(Output.folder.standardizedFileURL == tmp.standardizedFileURL)
            Output.folder = Output.defaultFolder
            #expect(UserDefaults.standard.string(forKey: Output.defaultsKey) == nil)
        }
    }

    @Test func newURLUsesPrefixExtensionAndTimestamp() {
        let url = Output.newURL(prefix: "Recording", ext: "mov")
        #expect(url.pathExtension == "mov")
        #expect(url.lastPathComponent.hasPrefix("Recording 20"))
        #expect(url.deletingLastPathComponent().standardizedFileURL == Output.folder.standardizedFileURL)
    }
}
