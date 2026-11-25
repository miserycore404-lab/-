# Line by Line

An Android app for learning things by heart: texts line by line, plus formulas,
definitions, theorems, rules and dates sorted by subject.

**Install:** download [`LineByLine.apk`](LineByLine.apk) on your Android phone and open it.
Android asks to allow installing from this source (your browser or Files app): allow it once.

## Features
- **Texts**: photo or paste → split into steps → Look & copy → Fade → From memory. Other methods: First letters, Puzzle, Say it (microphone). Chain mode links steps together.
- **Cards**: formulas (symbol keyboard, real superscripts: `a^2`, `x_1`, `x^{n-1}`), definitions, theorems, rules, facts/dates.
- **Practice**: Flashcards, Type it, Quiz, Fill the gaps, Match (timed), Practice tests with a score, Weak spots, Cheat sheet.
- **Exams**: add exam dates; a countdown shows on the home screen.
- **Focus timer**: 25/5 study sessions.
- **Spaced review**: everything comes back after 1, 3, 7, 14, 30, 60 days.
- **Daily reminder** notification, day streak, daily goal, 16-week activity map.
- **Starter packs**: algebra, geometry & trig, derivatives, physics, chemistry, cell biology, key dates, Romanian spelling.
- **Romanian** is the default language for new items (photo reading, voice, microphone). Menus are in English.
- **Backup & share**: save everything to a file, or send one subject's cards to a friend.

The Android app reads photos on the phone (no internet needed). The voice and microphone use the phone's
Google voice services; install the Romanian voice under Settings → Text-to-speech if it's missing.

## Project layout
- `app.html`: the whole app (UI and logic).
- `android/`: the Android shell (WebView + camera, ML Kit text recognition, text-to-speech, speech recognition, sharing, reminders).
- `index.html`, `manifest.webmanifest`, `sw.js`: the same app as an installable web page.

## Build the APK
```sh
android/build-web.sh                       # bundle app.html + fonts into the app
cd android && gradle assembleRelease      # needs the Android SDK (platform 35) and JDK 17+
```
Set `LBL_KEYSTORE` and `LBL_KEY_PASS` to sign with your own key; without them the debug key is used.
An update installs over the old app only when it is signed with the same key.
