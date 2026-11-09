# Snapshot

A lightweight macOS menu bar app for capturing, annotating, pinning and recording parts of your screen.

Press a hotkey, drag over the area you want, mark it up, and copy it, save it, pin it to your screen, or record it as a video.

## Features

- **Region capture** – freeze the screen, drag to select, then move or resize the selection with handles. Works across multiple displays and captures at full Retina resolution.
- **Annotations** – rectangles, arrows, freehand pen and text, with a color picker and undo.
- **Copy or save** – copy to the clipboard in one keystroke, or save a PNG to your chosen folder.
- **Pin to screen** – float a capture above your other windows. Drag to move, scroll to resize, change opacity from the right-click menu, and double-click to dismiss.
- **Screen recording** – record the selected area to an H.264 `.mov`, with the recorded region left clear and everything around it dimmed. A floating control bar beside the area gives you a timer, pause/resume, microphone mute, discard and stop.
- **Full-screen capture** – grab the whole display from the menu.
- **Delayed capture** – from the menu bar, **Capture After Delay** waits 3 or 5 seconds (with a countdown in the menu bar) before capturing an area or the full screen, so you can open a menu or hover state first.
- **Record Video from the menu** – **Record Video** and **Record Video After Delay** (3 or 5 seconds) open the area selector in video mode. Adjust the area, then press Return or the record button; the usual toolbar stays available.
- **Settings** – choose where screenshots and recordings are saved, and rebind the global capture shortcuts.

## Requirements

- macOS 15 or later
- Xcode (or a Swift 6 toolchain) with the macOS 15 SDK

## Build and run

```sh
./build.sh
open ~/Applications/Snapshot.app
```

The build script runs `swift build -c release`, assembles `build/Snapshot.app`, installs a copy to `~/Applications/Snapshot.app` (so Spotlight and Raycast can launch it), and signs it with a stable identity so macOS keeps its permissions between rebuilds.

Run the tests with:

```sh
swift test
```

To start Snapshot at login, add `~/Applications/Snapshot.app` under **System Settings → General → Login Items**.

### Permissions

The first time you capture, macOS asks for **Screen Recording** access. The first recording also asks for **Microphone** access; decline it to record without audio. Enable Snapshot under **System Settings → Privacy & Security → Screen Recording**, then quit and reopen the app.

## Usage

| Action | Shortcut |
| --- | --- |
| Start a capture | `⌥⇧A` (configurable) |
| Capture the full screen | `⌥⇧F` (configurable) |
| Copy selection | `Return` or `⌘C` |
| Save selection | `⌘S` |
| Pin selection | `⌘P` |
| Record selection | `⌘R` |
| Undo annotation | `⌘Z` |
| Cancel | `Esc` |
| Stop recording | Stop button on the control bar, or press the capture hotkey |

The same actions are available from the toolbar that appears beside your selection, and from the menu bar icon. Open **Settings…** from the menu to change the save folder and the global shortcuts.

While recording, macOS shows its own "Stop Sharing" control in the menu bar. Snapshot saves the video correctly whichever stop control you use.

## Project layout

Snapshot is a Swift package with one executable target and a test target. Code is grouped by feature, one type (or a small family of related types) per file.

```
Package.swift
build.sh                         Builds, bundles, signs and installs Snapshot.app
Sources/Snapshot/
  main.swift                     Entry point
  App/
    AppDelegate.swift            Launch-time wiring only
    MenuBarController.swift      Status item, menu, delay countdown, recording indicator
  Capture/
    CaptureController.swift      Owns the overlay windows; carries out copy/save/pin/record requests
    CaptureView.swift            Overlay state, drawing, mouse and keyboard
    CaptureView+Text.swift       Text annotation editing
    CaptureView+Toolbar.swift    Floating toolbar and tool/colour/undo actions
    CaptureView+Actions.swift    Rendering the selection and the copy/save/pin/record actions
    CaptureViewDelegate.swift    What the overlay asks of the app (keeps the view free of side effects)
    SelectionGeometry.swift      Pure geometry: handles, resize, move, toolbar placement
    Annotation.swift             Annotation model, colour palette and drawing
    ScreenGrabber.swift          screencapture wrapper
    OverlayWindow.swift
  Pin/                           Floating pinned screenshots
  Recording/
    Recorder.swift               ScreenCaptureKit session and AVAssetWriter output
    RecordingBar.swift           Floating timer/pause/mic/stop bar
    RecordingFrame.swift         Dimmed overlay that outlines the recorded area
  Hotkeys/
    HotKey.swift                 Shortcut model and the list of bindable actions
    HotKeys.swift                Carbon registration and persistence
    HotKeyField.swift            Shortcut recorder button used in Settings
  Settings/SettingsController.swift
  Support/                       Output (save folder, file names), Pasteboard, permission check, HUD container
Tests/SnapshotTests/             swift-testing suites for the pure logic
```

### Conventions

- **Dependencies point inward.** Views (`CaptureView`, `PinView`) don't call the recorder, the save folder or the clipboard directly. They tell a delegate or callback what the user asked for, and the controller decides what happens. `HotKeys` reports a `HotKeyAction`; `AppDelegate` decides what each one does.
- **Put logic in pure types.** Anything that can be computed from values (geometry, shortcut formatting, file naming) lives in a type with no views or global state, with tests in `Tests/SnapshotTests`. Keep views thin.
- **One feature, one folder.** A new capability (OCR, GIF export, a new annotation tool) gets its own file or folder and a single hook where it plugs in, rather than another branch in an existing type.
- **Run `swift test` and `./build.sh` before committing.** UI behaviour (overlay, recording) still needs a manual check.
