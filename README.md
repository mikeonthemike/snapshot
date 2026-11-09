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
- Swift command line tools (`xcode-select --install`)

## Build and run

```sh
./build.sh
open ~/Applications/Snapshot.app
```

The build script compiles the app into `build/Snapshot.app`, installs a copy to `~/Applications/Snapshot.app` (so Spotlight and Raycast can launch it), and signs it with a stable identity so macOS keeps its permissions between rebuilds. If your installed SDK is newer than your Swift compiler, adjust the `-sdk` path in `build.sh` to a matching one.

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

```
Sources/main.swift   The whole app: capture overlay, annotations, recorder, pinning, settings
build.sh             Builds and signs Snapshot.app
BACKLOG.md           Planned improvements
```

## Roadmap

See [BACKLOG.md](BACKLOG.md) for planned work, including system audio and GIF export.

## License

[MIT](LICENSE)
