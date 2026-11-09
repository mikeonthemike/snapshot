# Backlog

Ordered by priority: value to the user first, then effort, then what unblocks later items. Work top to bottom.

Done: launch at login toggle, copy text from screen (OCR), better annotations (pixelate, step numbers, highlighter).

## Next up

1. **Capture a window** — hover to highlight a window, click to capture, with optional shadow and rounded corners.
2. **Capture history** — recent captures in the menu bar with thumbnails; re-copy, re-pin or reveal in Finder.

## Then

3. **Selection helpers** — loupe/magnifier while selecting, and a colour picker mode.
4. **Post-capture actions** — choose per action whether a capture auto-copies, auto-saves or opens the editor; optional corner thumbnail with drag-out, edit and dismiss.
5. **Split `Recorder`** — separate the ScreenCaptureKit session from the queue-confined sample writer, and make the writer testable. Do this before items 6 and 7, which both touch it.
6. **Recording: GIF export** — export a recording as a GIF, for bug reports and PRs.
7. **Recording: system audio** — optional system audio alongside the microphone.
8. **Presets and file settings** — fixed-size and aspect-ratio selections, remember last region, file-name template, PNG/JPG/HEIC.

## Later

9. **Recording extras** — highlight clicks, show keystrokes, hide cursor toggle, webcam bubble, trim after recording.
10. **Scrolling capture** — auto-scroll and stitch long pages. Valuable but fiddly.
11. **Quick share** — upload or send a capture (for example to a Slack channel) and copy the link. Needs an auth design first.
