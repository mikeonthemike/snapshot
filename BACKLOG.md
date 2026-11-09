# Backlog

Ordered by priority: value to the user first, then effort, then what unblocks later items. Work top to bottom.

Done: launch at login toggle, copy text from screen (OCR), better annotations (pixelate, step numbers, highlighter), capture a window, toolbar icon tooltips, save-on-copy setting, capture history, loupe, arrow-key nudging, position readout.

## Next up

1. **Selection helper: colour picker** — a mode (menu item and rebindable hotkey) where hovering shows the colour under the cursor in the loupe and a click copies it. All formats: hex, RGB, HSL and HSB, plus CSS `rgb()`/`hsl()`; a key cycles the format and the last one is remembered. Pure colour-conversion code, tested.
2. **Selection helper: snapping** — selection edges snap to window and screen edges while dragging; hold ⌘ to turn snapping off. Reuses the window list from window capture.
3. **Post-capture actions** — choose per action whether a capture auto-copies, auto-saves or opens the editor; optional corner thumbnail with drag-out, edit and dismiss.
4. **Split `Recorder`** — separate the ScreenCaptureKit session from the queue-confined sample writer, and make the writer testable. Do this before items 5 and 6, which both touch it.
5. **Recording: GIF export** — export a recording as a GIF, for bug reports and PRs.
6. **Recording: system audio** — optional system audio alongside the microphone.
7. **Presets and file settings** — fixed-size and aspect-ratio selections, remember last region, file-name template, PNG/JPG/HEIC.

## Later

8. **Recording extras** — highlight clicks, show keystrokes, hide cursor toggle, webcam bubble, trim after recording.
9. **Scrolling capture** — auto-scroll and stitch long pages. Valuable but fiddly.
10. **Quick share** — upload or send a capture (for example to a Slack channel) and copy the link. Needs an auth design first.
