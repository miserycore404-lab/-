# Line by Line

A memorization app. Take a photo of a page (or paste text), and it walks you
through it one sentence at a time until you can write each one from memory.

Open `index.html` in a browser (phone or desktop). Edit `app.html`, then run
`./build.sh` to regenerate `index.html`.

- **Photo → text**: on-device OCR (Tesseract.js) or Claude when opened as a claude.ai artifact. You can fix the text before learning.
- **Methods**: Ladder (copy → fade → from memory), First letters, Puzzle (word order), Say it (microphone).
- **Chain**: after each step, recite the last few steps together.
- **Review**: learned lines come back on a spaced schedule (1, 3, 7, 14, 30 days).
- Progress is saved in the browser (localStorage).
