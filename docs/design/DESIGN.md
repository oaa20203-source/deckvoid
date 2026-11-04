# DeckVoid UI redesign: handoff for Claude Code

This folder holds the approved redesign of DeckVoid's launcher UI (the Qt Quick GUI in
`app/gui/`). It covers three screens and three input modes. Nothing in the app has been
changed yet. Implement it from this spec, check your work against the mockups, and ask
Omar before changing behaviour that is not described here.

## What's here

| File | What it is |
|---|---|
| `DESIGN.md` | This spec. Start here. |
| `tokens.json` | Every colour, font, size, radius and shadow. The source of truth for values. |
| `Theme.qml` | A reference QML singleton built from the tokens. Not wired in yet. |
| `mockups/<mode>-<screen>.png` | The target look: `controller`, `mac`, `ipad` × `hosts`, `pair`, `settings`. Rendered at 2×. |
| `deckvoid-style-picker.html` | The interactive picker Omar used to choose all of this. Open it in a browser to see any screen in any mode live. |

## The look in one paragraph

Pure white background, near-black warm text (#2A2420), soft pastel accents: mango
(#F7B267) is the main accent, orchid (#D7A6D9) is a small secondary touch. Headings are
Urbanist, body text is Quicksand. Corners are round (26px cards, 30px dialogs). Status
is shown by a coloured strip across the top of each PC card plus a dot before the status
word. Accent colours are never used for text, because they're too light to read on white.

## Screen mapping

| Design screen | Current code | Notes |
|---|---|---|
| Hosts | `app/gui/PcView.qml` | The PC grid. One card per host plus an "Add a PC" card, and a details strip for the selected PC underneath. |
| Pair with PIN | the PIN/passphrase pairing dialog in `PcView.qml` (backed by `computermodel.cpp`) | Modal dialog over a dimmed Hosts screen. |
| Settings: Stream | `app/gui/SettingsView.qml` | Left category list, right a grouped card of rows, preset chips top right. |

Keep all existing functionality, strings that carry meaning, and navigation. This is a
visual and input-mode redesign, not a feature change. If the mockups show data the app
doesn't have (for example "Last stream"), leave the slot out rather than inventing it, and
list it for Omar.

## Input modes: detect the device, then follow the last input used

Omar chose live switching. The UI has three modes and switches between them whenever a
different kind of input is used, the way Steam Big Picture does:

| Mode | Turns on when | Typical device |
|---|---|---|
| `controller` | any gamepad button press or stick movement past a deadzone | Steam Deck, or any device with a controller |
| `mouse` | mouse movement, a mouse click, or a keyboard key | Mac, desktop |
| `touch` | a touch on the screen | iPad, or the Steam Deck's touchscreen |

Starting mode before any input:

- Running on SteamOS / Steam Deck, or a gamepad is already connected: `controller`.
- Touch-first device (iOS/iPadOS build, if one exists): `touch`.
- Otherwise: `mouse`.

Implementation notes:

- `app/gui/sdlgamepadkeynavigation.cpp` already polls SDL gamepads to drive UI navigation.
  That's the natural place to report "controller used". Expose an `inputMode` property
  (for example on a theme or system-properties singleton) that QML binds to.
- Mouse and touch can be detected in QML with a top-level `HoverHandler` / `PointerHandler`
  checking `point.device.type` (Mouse vs TouchScreen), plus key events for keyboard.
- Add a small hysteresis: ignore a single stray mouse-move of a few pixels right after
  controller use, so a bumped trackpad doesn't flip the whole UI.
- Switching mode must not lose state: same screen, same selected PC, same scroll position.
- An iPad layout is included because Omar asked for it. Only apply it if there is (or will be)
  an iOS build. The `touch` rules still matter on the Steam Deck touchscreen.

## What changes per mode

### Controller (Steam Deck, 1280×800)
See `mockups/controller-*.png`.
- Header: logo left, `L1  Hosts  Settings  R1` tabs centred; the active tab has a 3px orchid underline.
- Focused card: lifts (scale 1.06, up 6px) with a soft shadow and a very thin mango glow. No outline.
- Focused inputs and settings rows use the smaller lift (up 3px, smaller shadow, same glow).
- Footer bar with controller glyph hints (A, X, Y, ≡, B) on the right, as now.
- Settings values change with ‹ › (D-pad left/right).

### Mouse (Mac, designed at 1440×900)
See `mockups/mac-*.png`.
- Standard macOS window chrome. Toolbar: logo, a segmented Hosts/Settings control centred,
  and on Hosts a search field and an "Add PC ⌘N" button on the right.
- No controller footer, no L1/R1 hints.
- Hovering a card lifts it slightly (up 4px) and reveals its actions: a primary button
  ("Stream ⏎", "Pair", "Wake") and a "•••" menu button. Picker option: Omar's current pick
  is "buttons appear on hover".
- Keyboard shortcuts appear next to button labels (⏎, ⌘N, esc).
- Settings rows use native-looking popup buttons (value + up/down chevrons), a normal slider
  with a numeric field for bitrate, smaller switches, and a segmented control for presets.
- The Pair dialog is a sheet attached to the top of the window.
- Type sizes × 0.86.

### Touch (iPad, designed at 1180×820 landscape)
See `mockups/ipad-*.png`.
- Nothing depends on hover or a focus highlight.
- Every PC card has one big visible action button (48px tall): "Stream" filled, "Pair" and
  "Wake" outlined.
- Round "+" button top right instead of "Add PC" text.
- Settings rows open with a › chevron; switches and slider thumbs are larger.
- The Pair dialog adds a large on-screen number pad next to the form for the PIN.
- All hit targets at least 44px. Type sizes × 0.96.

## Accessibility and quality bar

- Body and label text must meet 4.5:1 contrast on its background. The token text colours do.
- Colours that carry meaning (status) are always paired with a word.
- Every control stays reachable in all three modes: by D-pad/sticks in controller mode,
  by Tab/arrow keys in mouse mode.

## Fonts

Urbanist and Quicksand are free under the SIL Open Font License from Google Fonts.
Bundle the TTF/variable files in the app's resources (like the existing
`app/ModeSeven.ttf`) and load them with `FontLoader`. Fall back to the system sans-serif.

## Suggested order of work

1. Add `Theme` (from `Theme.qml`) and the two fonts, with no visual change yet.
2. Add the `inputMode` detection and expose it to QML.
3. Restyle `PcView.qml` (Hosts) for controller mode, check against `mockups/controller-hosts.png`.
4. Add the mouse and touch variants of Hosts.
5. Pair dialog, then Settings, the same way.
6. Build, run, and screenshot each screen in each mode. Compare against the mockups.
