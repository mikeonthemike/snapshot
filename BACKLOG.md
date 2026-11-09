# Backlog

Ordered by priority: value to the user first, then effort, then what unblocks later items. Work top to bottom.

Done: launch at login toggle, copy text from screen (OCR), better annotations (pixelate, step numbers, highlighter), capture a window, toolbar icon tooltips, save-on-copy setting, capture history.

## Next up

1. **Selection helpers** — loupe/magnifier while selecting, and a colour picker mode.
2. **Post-capture actions** — choose per action whether a capture auto-copies, auto-saves or opens the editor; optional corner thumbnail with drag-out, edit and dismiss.
3. **Split `Recorder`** — separate the ScreenCaptureKit session from the queue-confined sample writer, and make the writer testable. Do this before items 4 and 5, which both touch it.
4. **Recording: GIF export** — export a recording as a GIF, for bug reports and PRs.
5. **Recording: system audio** — optional system audio alongside the microphone.
6. **Presets and file settings** — fixed-size and aspect-ratio selections, remember last region, file-name template, PNG/JPG/HEIC.

## Later

7. **Recording extras** — highlight clicks, show keystrokes, hide cursor toggle, webcam bubble, trim after recording.
8. **Scrolling capture** — auto-scroll and stitch long pages. Valuable but fiddly.
9. **Quick share** — upload or send a capture (for example to a Slack channel) and copy the link. Needs an auth design first.
