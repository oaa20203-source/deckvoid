# DeckVoid design kit

Every DeckVoid screen follows this kit. If a screen needs something the kit
doesn't cover, add it here first, then design it.

## Where it comes from

Extracted from Omar's references: the 6 pins on his "website" board (not
Pinterest's "More like this" suggestions) and matthewencina.com.

1. National Gallery of Modern Art (NGMA) site: giant cropped wordmark over paintings,
   artworks placed alternately left and right with captions.
2. Pixel-art festival site: heavy wide display type ("artists."), mono body text,
   red on warm grey, section numbers ("03"), vertical text.
3. Hand-drawn product designer site: red line drawing on grid paper, dark frame.
4. "Stand out" illustrator site: one hand-made illustration breaking out of the photo.
5. Terrava: huge wordmark cut off by the bottom edge, muted greens.
6. mijonju.com: a "public notebook". Header split into ruled cells of small facts
   ("VERSION 0.71 / ALWAYS IN BETA"), heavy uppercase display, handwritten notes,
   flat colour blocks (pink, yellow, red-orange, blue) on paper, hard 1 px rules.
7. matthewencina.com: Aktiv Grotesk Bold at 130 px with -5% tracking, Fira Mono
   captions, warm grey / olive / near-black bands, one red button.

**What we take from them is styling, not their content or structure.** DeckVoid is
a working tool: the layout comes from what you do on each screen (pick a PC, start
or resume, pair, change a setting), and these references only decide how it looks:

- Heavy, tightly spaced grotesk type at large sizes for the one thing in focus.
- Small mono captions for facts (addresses, versions, numbers).
- Hard 1 px rules and ruled cells (mijonju), and flat cards, never shadows.
- Flat colour areas, one red accent, no gradients.

It is not a gallery, a catalogue, a portfolio or a dashboard. No decorative hero,
no big empty showcase areas, nothing on screen that isn't something you can read
or act on.

Research behind the rules:
- Munzner (2009), nested model: start from the user's task (pick a PC, start or
  resume, see if it will work), then decide the visuals.
- Larkin & Simon (1987): put related information in one place and let position
  carry meaning, instead of status sentences.
- IGenBench (ACL 2026): polish isn't proof of correctness. Show only data the
  app really has.

## Colour

| Token | Hex | From | Use |
|---|---|---|---|
| `soot` | `#282625` | Encina footer | Small dark areas only |
| `olive` | `#454539` | Encina "What I do" band | Rare: at most one small area per screen, never a main surface |
| `moss` | `#5F733C` | Terrava pin greens | Colour block on PC cards (Hosts). Green is welcome in blocks like this, just not as a main surface |
| `stone` | `#6E6965` | Encina hero band | Secondary surface, disabled text on bone |
| `ash` | `#EAE9E8` | Encina header | Light surface |
| `bone` | `#FAF9F6` | Encina text | Text on dark, lightest surface |
| `ink` | `#111111` | Encina | Text on light |
| `muted` | `#8A857F` | Encina greys | Captions on dark (≥ 4.5:1 on soot) |
| `vermilion` | `#E05D4E` | Encina button, pixel festival red | The main accent |
| `paper` | `#F1EEE9` | mijonju background | Main surface for every screen |
| `marigold` | `#F4C33F` | mijonju block | Category block only |
| `cobalt` | `#3B6FD6` | mijonju block | Category block only |

Rules:
- The app is mostly light: `paper` is the main surface, `ash` for secondary
  areas. `soot` is only for small dark areas (a list, a status strip), never a
  whole screen. Green (`moss`, `olive`) is used in blocks, never as a main surface
  (Omar: green is fine, there was just too much of it).
- Screens are built from **full-bleed colour areas**, not boxes on a background.
- `vermilion` appears **at most twice per screen**: the main action, and "live" state.
- Labels: `marigold` = running (an app is open on the PC), `vermilion` = manual /
  needs you (for example Add a PC), `ink` = state (online, paired), `ash` = neutral
  (APP). `marigold` and `cobalt` are otherwise only for category blocks.
- Never a gradient (photos are the only gradients).

## Type

Two families, nothing else: **IBM Plex Sans** (grotesk, stands in for Aktiv
Grotesk) and **IBM Plex Mono** (stands in for Fira Mono).

| Role | Font | Size / line / tracking | Notes |
|---|---|---|---|
| Display | Plex Sans Bold | 120–160 / 0.9 / -5% | The PC or game name. May be cropped by the screen edge. |
| Title | Plex Sans Bold | 40 / 1.0 / -3% | Section heads |
| Body | Plex Sans Regular | 19 / 1.4 / -2% | Max 52 characters per line |
| UI | Plex Sans Medium | 16 / 1.2 / -1% | Buttons, list rows |
| Caption | Plex Mono Regular | 13 / 1.3 / 0 | Addresses, versions, numbers, "01", times |

Rules:
- Sentence case for body and buttons. Display may be lowercase ("artists.") or
  uppercase (mijonju), never title case.
- No italics. No serif. No letter-spaced uppercase labels above headings.
- Numbers, addresses and versions are always in mono.

## Space and grid

- Steam Deck canvas 1280 × 800. Outer margin 32 px. 12 columns, 16 px gutters.
- Base unit 8 px; vertical rhythm in 8s, but **positions are deliberately uneven**:
  display type starts at column 1, body text at column 2 or 3, imagery spans
  columns 7–12 and bleeds off the edge.
- At least one element per screen breaks the grid (cropped display type, image
  bleeding off the edge, or text overlapping an image).
- Never centre a whole screen. Never three equal columns.

## Components

- **Bands:** full-width colour areas.
- **Card (mijonju style):** flat, 1 px rule border (`ink` 15% on light, `bone` 20%
  on dark), 4 px radius at most, no shadow. Optional real image on top, a small
  flat label, a title, a mono caption, and an arrow at the bottom right. Selected
  card: 2 px outline, 4 px offset. Cards can differ in size; never three identical
  cards in a row as the whole layout.
- **Fact header:** the top bar is a row of cells split by 1 px rules, each holding
  one small fact in mono (app version, "nightly build", PCs online). From mijonju.
- **App art:** real app art from the host, shown where you choose an app. Never
  decorative.
- **List row:** text on a band, separated by 1 px rules (`bone` at 20% on dark,
  `ink` at 15% on light). Mono index on the left ("01"). No row backgrounds.
- **Primary button:** `vermilion` fill, `bone` text, 48 px tall, 4 px radius,
  sentence-case verb that says what happens ("Resume Steam Big Picture").
- **Secondary action:** text link in Plex Sans Medium with an arrow (→ or ↗).
  No outlined boxes.
- **Focus (controller and keyboard):** 2 px `bone` (or `ink`) outline, 4 px offset,
  square corners. No glow, no scale-up, no shadow.
- **Status:** a plain word in mono next to the name ("online", "asleep",
  "not paired"). `vermilion` only for "live" (streaming now).
- **Controller hints:** mono captions at the bottom edge: `A resume  X pair  Y wake`.
  Never on buttons.
- **Radius:** 0 for bands and images, 4 px for buttons and cards. Nothing else is rounded.
- **Shadows:** none.

## Screens and launch

- **Launch screen: Hosts** (Omar, 4 November 2026). It echoes the Apps screen
  (page title with a link beside it, flat cards with a small label) but is not
  identical, and has no explanatory text column: PC cards are horizontal, show status
  instead of "running now", and there is a separate Add a PC card.
- "← PCs" on Apps goes to Hosts. The fact header shows the PC's name and how many
  apps it reported, never a build or version label.

## Copy

- Headlines are the real thing: the PC's name, the game's name. No slogans.
- Say what will happen: "Resume Steam Big Picture", "Wake Living-room PC".
- Captions are facts: `Vibepollo 2.0.6 · 10.131.6.18`.
- Banned phrases: "Unlock", "Seamless", "Get started", "Your PCs",
  "Pick a PC to stream from", "Elevate", "Experience", any welcome message.

## Data honesty

Only show values DeckVoid actually has: PC name, online / asleep / paired state,
running app, app list and its art, address, host software when the PC reports it.
No invented latency, session length or loss figures until the app records them.
Mockups use Omar's real PC (`DESKTOP-7SIOCH7`, `10.131.6.18`, Steam Big Picture);
any other PC in a mockup is labelled as an example.

## Banned

Gradients. A row of three identical cards as the whole layout. Cards inside cards.
Drop shadows and soft glows. Rounded corners above 4 px.
Monitor / computer icons as illustrations. Icon tiles. Pill tabs.
Coloured side stripes on selected rows. Eyebrow labels and small-caps kickers.
Pulsing dots and status chips.
Italic serif display type. Blue accents. Inter, Roboto, Poppins, Manrope,
Fraunces, SF Pro. Emoji. Centred hero layouts. Perfect symmetry.
Placeholder copy and invented numbers. Handwritten notes or asides
(Omar, 4 November 2026: they don't make sense in an app). Dashboards (stat grids, metric tiles).
Gallery, catalogue or portfolio layouts. Decorative heroes.
(Note: the impeccable.style list bans beige backgrounds, but Omar's own references
use warm paper, so `paper` is allowed. What stays banned is paper plus soft
shadows and heavily rounded cards.)

## Approved

- Section 03 (components) of the kit sheet approved by Omar on 4 November 2026:
  vermilion primary button, text link with arrow, 2 px focus outline, mono
  controller hints, ruled list with mono index and status word, flat lettered
  category blocks.
