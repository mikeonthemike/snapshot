# Snapshot

A lightweight macOS menu bar app for capturing, annotating, pinning and recording parts of your screen.

Press a hotkey, drag over the area you want, mark it up, and copy it, save it, pin it to your screen, or record it as a video.

## Features

- **Region capture** – freeze the screen, drag to select, then move or resize the selection with handles. Works across multiple displays and captures at full Retina resolution.
- **Annotations** – rectangles, arrows, freehand pen and text, with a color picker and undo.
- **Copy or save** – copy to the clipboard in one keystroke, or save a PNG to your chosen folder.
- **Pin to screen** – float a capture above your other windows. Drag to move, scroll to resize, change opacity from the right-click menu, and double-click to dismiss.
- **Screen recording** – record the selected area to an H.264 `.mov`, with the recorded region left clear and everything around it dimmed.
- **Full-screen capture** – grab the whole display from the menu.
- **Settings** – choose where screenshots and recordings are saved.

## Requirements

- macOS 13 or later
- Swift command line tools (`xcode-select --install`)

## Build and run

```sh
./build.sh
open build/Snapshot.app
```

The build script compiles the app, wraps it in `build/Snapshot.app`, and signs it with a stable identity so macOS keeps its permissions between rebuilds. If your installed SDK is newer than your Swift compiler, adjust the `-sdk` path in `build.sh` to a matching one.

To start Snapshot at login, add `Snapshot.app` under **System Settings → General → Login Items**.

### Permissions

The first time you capture, macOS asks for **Screen Recording** access. Enable Snapshot under **System Settings → Privacy & Security → Screen Recording**, then quit and reopen the app.

## Usage

| Action | Shortcut |
| --- | --- |
| Start a capture | `⌥⇧A` |
| Copy selection | `Return` or `⌘C` |
| Save selection | `⌘S` |
| Pin selection | `⌘P` |
| Record selection | `⌘R` |
| Undo annotation | `⌘Z` |
| Cancel | `Esc` |
| Stop recording | Click the stop control in the menu bar, or press `⌥⇧A` |

The same actions are available from the toolbar that appears beside your selection, and from the menu bar icon. Open **Settings…** from the menu to change the save folder.

While recording, macOS shows its own "Stop Sharing" control in the menu bar. Snapshot saves the video correctly whichever stop control you use.

## Project layout

```
Sources/main.swift   The whole app: capture overlay, annotations, recorder, pinning, settings
build.sh             Builds and signs Snapshot.app
BACKLOG.md           Planned improvements
```

## Roadmap

See [BACKLOG.md](BACKLOG.md) for planned work, including a floating recording controller, a configurable hotkey, and audio and GIF export.

## License

[MIT](LICENSE)
