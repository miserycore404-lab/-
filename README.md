# КОРДОН · CORDON

A first-person narrative game in Godot 4.3+ (Forward+). December 1991, a forest
cordon at the 101st kilometre outside Moscow. Russian and English throughout.
The story bible is in [docs/STORY.md](docs/STORY.md).

Everything is generated in code: geometry, shaders, all sound effects, and a
generative piano score. The only assets are the fonts (OFL, in `assets/fonts`).

## Run

Open the folder in Godot 4.3 or newer and press F5. The main scene is
`scenes/main_menu.tscn`.

**Controls:** WASD to move · Shift to run · Ctrl/C to crouch · E/LMB to interact
(E also sips a held drink) · F for the flashlight · Tab for the notebook ·
1–3 or the mouse wheel for dialogue replies · Esc to pause. Every key can be
rebound in Settings → Controls.

## Layout

| Path | Contents |
|---|---|
| `scripts/core/` | Autoloads: `Settings`, `Loc` (RU/EN), `Sfx` (procedural audio and music), `Fader`, `Game` (state and saves) |
| `scripts/data/` | `strings.gd` (UI text), `story_data.gd` (prologue, dialogues, thoughts, documents, objectives) |
| `scripts/world/` | Terrain, forest, cabin, props, train, bullfinches, footprints, materials, `MeshKit` |
| `scripts/player/` | Controller and the IK-driven first-person body |
| `scripts/ui/` | Main menu, prologue, settings, pause, HUD, dialogue runner, end screen |
| `scripts/story/director.gd` | Chapter scripts (coroutines) |
| `shaders/` | Snow, wood, foliage, bark, sky, ice, frost glass, carpet, transition, film grain |
| `tests/` | Headless test scenes (parse check, world renders, scripted play-through) |

## Status (end of session 1)

**Done and verified:**
- All scripts compile (`tests/parse_all.tscn`).
- The main menu renders and looks right.
- The world renders: terrain, forest, cabin exterior and interior, porch, woodshed, train.
- Chapter 1 runs from the opening card into the cabin: thoughts, objectives, door, lamp and firewood steps.

**Written but not yet verified end-to-end:**
- The second half of Chapter 1 (stove, radio dialogue, coffee, log, sleep).
- Chapters 2 and 3, the epilogue, the prologue screen, the settings menu and the pause menu.

**Fixed after the last screenshots, not yet re-checked:**
- HUD centring: subtitles, the chapter card and the reader sat at the top-left; changed to explicit anchors.
- The first-person body pose (looking down showed the inside of a collar).
- Softer snow on logs and dimmer train windows.
- Sky moved off REALTIME mode, forest chunked with LODs. Both are for performance.

**Next up:**
- Re-run `tests/autotest.tscn` (modes: menu, settings, prologue, ch1, ch2, ch3) and fix what turns up.
- Polish the stove front, the pine crowns and the interior lighting balance.
