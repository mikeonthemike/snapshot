# Backlog

Ordered by priority: value to the user first, then effort, then what unblocks later items. Work top to bottom.

Done: launch at login toggle, copy text from screen (OCR).

## Next up

1. **Better annotations** — blur/pixelate to redact, numbered step markers, highlighter. Do this by turning `Tool` into a small tool abstraction first, so each new tool is one file.
2. **Capture a window** — hover to highlight a window, click to capture, with optional shadow and rounded corners.
3. **Capture history** — recent captures in the menu bar with thumbnails; re-copy, re-pin or reveal in Finder.

## Then

4. **Selection helpers** — loupe/magnifier while selecting, and a colour picker mode.
5. **Post-capture actions** — choose per action whether a capture auto-copies, auto-saves or opens the editor; optional corner thumbnail with drag-out, edit and dismiss.
6. **Split `Recorder`** — separate the ScreenCaptureKit session from the queue-confined sample writer, and make the writer testable. Do this before items 7 and 8, which both touch it.
7. **Recording: GIF export** — export a recording as a GIF, for bug reports and PRs.
8. **Recording: system audio** — optional system audio alongside the microphone.
9. **Presets and file settings** — fixed-size and aspect-ratio selections, remember last region, file-name template, PNG/JPG/HEIC.

## Later

10. **Recording extras** — highlight clicks, show keystrokes, hide cursor toggle, webcam bubble, trim after recording.
11. **Scrolling capture** — auto-scroll and stitch long pages. Valuable but fiddly.
12. **Quick share** — upload or send a capture (for example to a Slack channel) and copy the link. Needs an auth design first.
