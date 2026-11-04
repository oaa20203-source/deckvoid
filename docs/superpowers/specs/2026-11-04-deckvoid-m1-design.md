# DeckVoid: build guide for the implementing agent

Status: design approved in conversation on 2026-11-04 (sections 1 and 2); sections 3 to 5
were written here for the owner's review. Treat this file as the spec and the plan for
milestone 1. Copy it into the repository as `docs/superpowers/specs/2026-11-04-deckvoid-m1-design.md`
once the repository exists.

## 0. Read this first

**What DeckVoid is.** A Moonlight client for the Steam Deck OLED, built on Nonary's
moonlight-qt "VRR" fork, that is fully compatible with Apollo and Vibepollo hosts and later
reproduces the parts of VoidLink's in-stream experience that matter on a handheld.

**Who owns it.** Omar (GitHub `oaa20203-source`). Public release eventually. The owner
streams from a Windows PC running Vibepollo to a Steam Deck OLED 1 TB (90 Hz panel).

**How to work with the owner.** They asked to be consulted constantly and to see the
interface as it is built. Concretely:
- Before each task in section 10, say in two lines what you are about to change.
- After every UI change, build the macOS dev binary, run it, take a screenshot, and
  send it. Do the same on the Deck once the Flatpak builds.
- Ask before: installing anything with Homebrew, creating the GitHub repositories,
  pushing, changing the Flatpak ID, or anything that touches their Deck beyond
  installing the Flatpak to the user scope.
- Prefer `AskUserQuestion` with concrete options over open questions.

**Engineering rules.** Test-driven for every parser, URL builder, hash and packet (Qt Test,
section 9). No feature may regress Nonary's VRR, PyroWave or haptics paths: keep the Apollo
code in its own directory and keep hooks minimal so rebasing onto Nonary's next tag is a
small merge. Never log PINs or passphrases. Never guess endpoints; everything the host
accepts is listed in section 4 with source references.

**Decisions already made (do not reopen).**

| Decision | Value |
|---|---|
| Product name | DeckVoid |
| Binary / qmake TARGET | `deckvoid` |
| Flatpak app ID | `io.github.oaa20203_source.deckvoid` (hyphen becomes underscore; Flathub rule) |
| GitHub repos | `oaa20203-source/deckvoid` (app) and `oaa20203-source/moonlight-common-c` (library fork) |
| Base | `Nonary/moonlight-qt` master `76ee5025` (2026-10-30), chosen by the owner on 2026-11-04 because `launchwarning.h`, `poweractions.h`, `tests/power/tlsfixture.h` and the Deck buffering work are not in tag `v6.1.0-vrr18`. Section 5 line numbers come from this commit. |
| Library base | `Nonary/moonlight-common-c` at the commit the base pins as a submodule |
| Milestones | M1 Apollo layer, M2 Deck OLED performance and haptics, M3 in-stream menu / toolbox / touch and gyro profiles, M4 Vibepollo extras |
| Not using | Artemis Qt code (reference only), VoidLink's `voidlink-c` library (collides with Vibepollo IDs) |

## 1. Product summary

Milestone 1 makes DeckVoid a first-class Apollo client. When it is done, from the Deck
you can: pair with a PIN and passphrase generated in the host's web UI without touching
the PC; see the apps in the order the host owner arranged; launch an app on a virtual
display or the physical one, with a host-side scale factor; run the host's server
commands and sync the clipboard from a minimal in-stream menu; and get a clear message
when the host denies a permission instead of a generic failure.

Milestone 2 (not specified here, see section 12) is what the owner cares about most:
smoothness, responsiveness, haptics, and fidelity per megabit on a 1280x800 90 Hz panel.
Milestone 1 is first because it is small and unblocks testing the real host.

## 2. Source material

Everything below was read from source; nothing was executed. Clone fresh; do not rely on
any temporary checkout.

| Source | Where | Why it matters |
|---|---|---|
| Vibepollo 2.0.6 (host, fork of Apollo) | `~/omar_apollo/Vibepollo-2.0.6.zip` (unzip into its own directory) | The protocol oracle. All host-side references in section 4 are `src/...` paths inside it. |
| Nonary/moonlight-qt | `https://github.com/Nonary/moonlight-qt` | The base. Read `AGENTS.md`, `architecture.md`, `docs/pyrowave-protocol.md`, `docs/steam_controller.md`, `docs/steamos-vrr.md`. |
| Nonary/moonlight-common-c | submodule of the above | Gets one new packet type. |
| ClassicOldSong/moonlight-common-c (Apollo's library fork) | `https://github.com/ClassicOldSong/moonlight-common-c`, commit `c999436` | Reference for `LiSendExecServerCmd` and the 0x3000-0x3002 packet table. |
| Artemis Android 20.2.6 | `~/omar_apollo/moonlight-android-20.2.6.zip` | Reference for OTP (`PairingManager.java:187-226`), clipboard (`NvHTTP.java:922-937`), launch params (`NvHTTP.java:849-903`), game menu (`GameMenu.java`). Its common-c submodule directory is empty in the zip. |
| wjbeckett/artemis ("Artemis Qt") | `https://github.com/wjbeckett/artemis`, commit `afe2de7` | Map of Qt touch points only. Do not copy code; see section 11. |
| VoidLink (iOS) | `https://github.com/The-Fried-Fish/VoidLink-previously-moonlight-zwm`, branch `Integration` | UI reference for milestone 3. No Apollo integration; its host extensions target Sunshine-Foundation. The zip in the folder is the wrong branch. |
| Apollo wiki | `https://github.com/ClassicOldSong/Apollo/wiki` (Permission System, Server Commands, Client Commands) | Human-readable behaviour descriptions. |

## 3. Architecture

```
deckvoid/                         fork of Nonary/moonlight-qt
  app/backend/apollo/             NEW, all Apollo-specific code
    apollohostinfo.h              header-only /serverinfo parser (like framelimitercapabilities.h)
    apollopermissions.h           bit constants + helpers + user-facing names
    apollolaunchoptions.h         struct passed into NvHTTP::startApp
    apolloclipboard.h/.cpp        ClipboardSync owned by Session
    apolloconstants.h             special app IDs/UUIDs (input-only UUID, notice ID 114514)
  app/backend/nvhttp.*            hooks: startApp params, clipboard endpoints, 403/410 mapping
  app/backend/nvcomputer.*        ApolloHostInfo field, isApollo(), sortAppList by index
  app/backend/nvapp.*             uuid, index, artVersion
  app/backend/nvpairingmanager.*  optional OTP passphrase
  app/backend/computermanager.*   pairHostWithOtp
  app/settings/streamingpreferences.*  new prefs (section 6.4)
  app/gui/PcView.qml, AppView.qml, SettingsView.qml, QuickMenu overlay (section 6)
  app/streaming/session.*         execServerCommand, clipboard triggers, quick menu v0
  moonlight-common-c/             submodule -> oaa20203-source/moonlight-common-c
```

Principles: Apollo logic in `app/backend/apollo/` is plain C++ with no Qt GUI
dependencies so it is unit-testable; `NvHTTP`, `NvComputer`, `Session` only call into it.
Everything is gated on `NvComputer::isApollo()` so Sunshine and GeForce hosts behave exactly
as in the base.

## 4. Protocol contract (what the host accepts)

Verified against Vibepollo 2.0.6 source. Items marked "Apollo" are inherited from Apollo
(code comments in `src/stream.cpp:134-142` and `src/nvhttp.cpp:4278` say so); items marked
"Vibepollo" exist only there and are out of scope for M1 unless stated.

### 4.1 Host detection
Vibepollo emits no `ApolloVersion` tag (only `appversion`, `src/nvhttp.cpp:4236`). Detect
Apollo-family hosts by the presence of `VirtualDisplayCapable` or `Permission` in
`/serverinfo`. Keep the base's Sunshine detection (`IS_SUNSHINE()` = negative fourth
version component, `Limelight-internal.h:88`).

### 4.2 `/serverinfo` fields to read (`src/nvhttp.cpp:4216-4446`)
| Tag | When present | Meaning |
|---|---|---|
| `Permission` | paired HTTPS (plain HTTP gives `0`) | decimal bitmask, section 4.3 (`:4319-4322`) |
| `ServerCommand` (repeated) | paired HTTPS and `server_cmd` bit | command names; **list position = index for packet 0x3000** (`:4304-4317`) |
| `VirtualDisplayCapable`, `VirtualDisplayDriverReady`, `VirtualDisplayHDRCapable` | always | strings `true`/`false` (`:4277-4294`) |
| `currentgameuuid` | always | UUID of the running app, empty if none (`:4430`) |
| `currentgame`, `state`, `appversion`, `GfeVersion`, `HttpsPort`, `ExternalPort`, `mac`, `ServerCodecModeSupport` | stock | already parsed by the base |
| `FrameLimiter*`, `PowerActionVersion`, `Sleep*`, `PyroWave*`, `HardwareMetricsVersion` | Vibepollo | already parsed or M4 |

Multi-client note: the running game is only reported to the client that owns it; other
paired clients see `SUNSHINE_SERVER_FREE` with `currentgame=0` (`:4401-4436`).

### 4.3 Permission bits (`src/crypto.h:48-77`, Apollo)
| Bit | Name | Client use |
|---|---|---|
| 0x100 | input_controller | informational |
| 0x200 | input_touch | informational |
| 0x400 | input_pen | informational |
| 0x800 | input_mouse | informational |
| 0x1000 | input_kbd | informational |
| 0x10000 | clipboard_set | enables push clipboard |
| 0x20000 | clipboard_read | enables pull clipboard |
| 0x40000 | file_upload | not used |
| 0x80000 | file_dwnload | not used |
| 0x100000 | server_cmd | enables server-command menu |
| 0x1000000 | list | app list |
| 0x2000000 | view | view streams (Remote Monitor resume in M4) |
| 0x4000000 | launch | launch and terminate apps |
Default for a newly paired client is `view | list`. There is no separate "terminate"
bit; `launch` covers quit (`src/nvhttp.cpp:4689-4691`).

### 4.4 `/applist` (`src/nvhttp.cpp:4617-4777`, Apollo)
Each `<App>` carries `UUID`, `IDX`, `ArtVersion` in addition to `ID`, `AppTitle`,
`IsHdrSupported`. Without the `list` permission the host returns one fake app with
`ID=114514` whose title explains the problem (`:4762-4775`). Vibepollo adds synthetic
"control tiles" (IDs 2147483501-2147483507, UUIDs `9a1c5a25-58fe-40e0-b9aa-7d3f0000000N`);
in M1 they are shown as ordinary apps, handled properly in M4.

### 4.5 `/launch` and `/resume` (`src/nvhttp.cpp:3053-3493`, Apollo unless noted)
Required by the host: `rikey`, `rikeyid`, `localAudioPlayMode`, and `appid` or `appuuid`;
the TLS client certificate must be paired (`:4816-4835`).

Add to the base's query string:
| Parameter | Value | Notes |
|---|---|---|
| `appuuid` | app UUID | identity resolved by UUID first (`:3288-3297`); keep sending `appid` for Sunshine |
| `mode` | `WxHxR` | `R` may be an integer Hz, a decimal with up to 3 fractional digits (`59.94`), or millihertz if 1000 or more (`59940`). Range 10000-1000000 mHz (`:3154-3241`). Fallback on parse failure is 1920x1080x60. |
| `virtualDisplay` | `0` or `1` | explicit override (`:3302-3307`); `0` yields `<clientWarning>virtual_display_disabled_by_client</clientWarning>` in a successful reply (`:2955-3008`) which the base already parses (`app/backend/launchwarning.h`) |
| `scaleFactor` | 20-200, default 100 | scales the host virtual display, stream resolution unchanged (`:3422-3465`). Do **not** also scale on the client. |
| `clientName` | string | only applied if the paired record has no name (`:3102-3109`) |
| `clientVrrRequested` | `1` | Vibepollo; the base already sends it |
Reply fields: `sessionUrl0`, `gamesession=1` (or `resume=1`), `VirtualDisplayDriverReady`,
`clientWarning`. Status codes with `status_message`: 400, 403 (permission), 404, 409
(conflict), 410 (Vibepollo control tiles: success-with-message, M4), 500, 503 (retry).

### 4.6 Every request
Base `openConnection` already appends `uniqueid=<client id>&uuid=<random>`. Add
`devicename=<client name>` to pairing requests (host reads it in `/pair`,
`src/nvhttp.cpp:3989-4142`; `roth` is mapped to "Legacy Moonlight Client").

### 4.7 OTP pairing (`src/nvhttp.cpp:4054-4082`, Apollo)
Host side: the owner creates a 4-digit PIN with a passphrase (min 4 chars) and a device
name via the web UI (`POST /api/otp`, 180 s lifetime, `src/confighttp.cpp:5030-5056`).
Client side: on the first pairing request (`phrase=getservercert`) add
```
otpauth=<uppercase hex of SHA-256( pin + saltHex + passphrase )>
```
where `saltHex` is the same `salt=` value sent in that request (16 random bytes, hex).
The user-entered PIN replaces the client-generated one. Everything else in the pairing
handshake is unchanged. If the hash mismatches the host still answers positively and the
later challenge steps fail; if no OTP is active the host returns 503
"OTP auth not available". Reference: Artemis `PairingManager.java:212-226`.

### 4.8 Server commands (Apollo)
Discovery: `ServerCommand` list (4.2). Execution: control-stream packet type **`0x3000`**,
payload `{ uint8 index, 0, 0, 0 }`, reliable, ENet channel `CTRL_CHANNEL_SERVERCTL = 0x08`
(Apollo `Limelight-internal.h:64`; Nonary's `CTRL_CHANNEL_COUNT` is 0x30 so the channel
exists). Host handler `src/stream.cpp:1890-1925` checks the `server_cmd` bit and the index
range, runs the command, returns nothing. Apollo's library packet table
(`ControlStream.c:234-237`): `0x3000` exec server cmd, `0x3001` set clipboard,
`0x3002` file-transfer nonce. Vibepollo accepts 0x3001/0x3002 but **ignores their payload**
(`src/stream.cpp:1927-1943`), so clipboard must use HTTPS.

### 4.9 Clipboard (Apollo)
`GET  /actions/clipboard?type=text` returns host clipboard text (`src/nvhttp.cpp:6860-6903`).
`POST /actions/clipboard?type=text` with a `text/plain` body sets it (`:6905-6959`).
Both: HTTPS with the pinned certificate, the matching permission bit, and an **active
stream from the same certificate** (403 otherwise); any `type` other than `text` is 400.
Reference: Artemis `NvHTTP.java:922-937`.

### 4.10 Input-only app (Apollo legacy)
UUID `8CB5C136-DA67-4F99-B4A1-F9CD35005CF4` is a virtual "Remote Input" app offered when
the host enables `enable_input_only_mode` (`src/legacy_generated_app_identities.h:9`,
`src/nvhttp.cpp:5339`). M1 behaviour: launching it must not quit a running game. Full
video-less sessions are M4.

## 5. Hook map in the base (Nonary/moonlight-qt master `76ee5025`)

Line numbers drift; search for the function names.

| Purpose | Location |
|---|---|
| `/serverinfo` parsing | `NvComputer::NvComputer(NvHTTP&, QString serverInfo)` `app/backend/nvcomputer.cpp:132-231`; style examples `FrameLimiterCapabilities::fromServerInfo` (`framelimitercapabilities.h:9-33`), `PowerActions::advertised` (`poweractions.h:40-49`) |
| `NvComputer` fields and `update()` | `nvcomputer.h:21-129`; `ASSIGN_IF_CHANGED` macros `nvcomputer.cpp:547-560`, fork fields at `:580-586` |
| Serialization | `SER_*` `nvcomputer.cpp:12-26`, `serialize()` `:79-106`; `NvApp` keys `nvapp.cpp:3-8` |
| App sorting | `NvComputer::sortAppList()` `nvcomputer.cpp:125-130`, called at `:54` and `:498`; `updateAppList` `:482-500` |
| App list fetch | `NvHTTP::getAppList()` `nvhttp.cpp:455-505` |
| Launch URL | `NvHTTP::startApp(...)` `nvhttp.cpp:343-401`; query block `:363-392`; `LaunchWarning::parse` at `:400` |
| HTTP plumbing | `openConnection` `nvhttp.cpp:661-865` (uniqueid/uuid at `:684-686`; power requests skip them); `openConnectionToString` `:637-659`; `verifyResponseStatus` `:507-544`; `GfeHttpResponseException` `nvhttp.h:35-68` |
| Fork-added endpoint example | `NvHTTP::requestHostSleep()` `nvhttp.cpp:612-635` (power-actions, pinned cert, POST with token) |
| Pairing | `NvPairingManager::pair(appVersion, pin, serverCert)` `nvpairingmanager.cpp:206-372`; `getservercert` request `:233-237` (`devicename=roth`); signature check `:321-328`; PIN check `:330-339`; `PairState` enum `nvpairingmanager.h:12-17` |
| Pairing task and PIN display | `PendingPairingTask` `computermanager.cpp:577-634`; `pairHost` `:636-642`; `generatePinString` `:1048`; QML entry `computermodel.cpp:199,233`; `PcView.qml:236-243` shows the PIN; `pairDialog` `PcView.qml:291-304` |
| Sleep task pattern to mirror | `PendingSleepTask` `computermanager.cpp:702-725`, `requestHostSleep` `:727-740`, signal `hostSleepCompleted` `computermanager.h:260` |
| PC context menu | `PcView.qml:164-219` (`NavigableMenuItem`s) |
| App grid and context menu | `AppView.qml:83` grid, `:219` launch, `:316-355` context menu; synthetic sleep row `appmodel.cpp:97-111`, roles `appmodel.h:17-26` |
| Settings page | `SettingsView.qml`: GroupBox pattern, "Host Settings" box `:2070-2108`, CheckBox example `quitAppAfter` `:2092-2106`, ComboBox example `languageComboBox` `:2129-2295` |
| Preferences | `streamingpreferences.h:189,260,325` and `.cpp:50,231,463` for `quitAppAfter` (Q_PROPERTY, member, signal, SER key, reload default, save) |
| Launch trigger | `Session::startConnectionAsync()` `session.cpp:1812`; `http.startApp(...)` `:1847-1858`; `displayLaunchError` `:1859-1864` |
| Stream window and loop | `Session::exec()` `session.cpp:2097`; window `:2166`; overlay setup `:2283`; launch warning overlay `:2311-2321`; event loop `:2323`; key/controller dispatch `:2664-2710` |
| Keyboard combos | `input/input.h:151-164` enum; registration `input/input.cpp:80-83`; detection `input/keyboard.cpp:195-224`; `performSpecialKeyCombo` `keyboard.cpp:16` |
| Gamepad chords | `input/gamepad.cpp:258-421`; quit `:369-383`; stats `:386-399`; graph `:401-412` |
| Overlay API | `video/overlaymanager.h:17-80` (`OverlayDebug`, `OverlayStatusUpdate`, `setStatusMessage`, renderer pull model) |
| Control stream packet tables | `moonlight-common-c/src/ControlStream.c:143-157` IDX list, tables `:165-249` (five tables; Gen7Enc `:233-249`), `sendMessageAndForget` `:882`, send-and-forget example `confirmLongtermReferenceFrame` `:1703-1720`; public prototypes `Limelight.h` near `:1215` |
| Tests | `tests/tests.pro` (subdirs, opt-in with `CONFIG+=tests`); example `tests/power/poweractions.pro`, `tst_poweractions.cpp`, loopback TLS `tlsfixture.h`; README in `tests/power` |
| Branding | `app/app.pro:5-8` TARGET, `:38-42` version; `app/main.cpp:464-471` names, `:1003` desktop file; `app/deploy/linux/*.desktop` and `.appdata.xml`; `packaging/flatpak/com.moonlight_stream.Moonlight.json`; `.github/workflows/build-flatpak.yml`, `build-release.yml`; `.github/ISSUE_TEMPLATE/bug_report.md` |
| CI | `build.yml` (tests + calls), `build-appimage.yml`, `build-flatpak.yml`, `build-win-mac.yml`, `build-steamlink.yml`, `build-release.yml`, `daily-prerelease.yml` (gated on `github.repository == 'Nonary/moonlight-qt'`) |

## 6. Milestone 1 user interface (owner to review)

Build the macOS dev binary and screenshot each of these for the owner before moving on.

### 6.1 Pairing
- PC context menu gains **"Pair with PIN and passphrase..."** under the existing items,
  shown for unpaired hosts. The existing click-to-pair flow is unchanged.
- Dialog (a `NavigableDialog`): two fields, PIN (4 digits, numeric) and passphrase
  (masked, min 4 chars), text "Create these in the host's web UI under Devices > Add
  device (OTP)", buttons Pair / Cancel. On success the dialog closes and the host shows
  as paired; on failure the existing error dialog shows the `PairState` text.
- "View Details" gains a **Permissions** block listing the human names of granted bits
  when the host is Apollo.

### 6.2 App grid
- Apps ordered by host `IDX` when `isApollo()`.
- The ID 114514 notice app renders as a non-launchable tile with the host's message.
- Context menu on an app, when the host is Apollo and virtual display is capable:
  **"Launch on virtual display"** / **"Launch on physical display"** (the one that is not
  the current default) in addition to the stock Launch/Resume. If the driver is not ready
  (`VirtualDisplayDriverReady=false`) show a confirm dialog and allow proceeding.

### 6.3 Quick menu v0 (in-stream)
A minimal, gamepad-navigable text list drawn by the existing overlay renderer, seed of the
M3 radial menu. Opened with gamepad chord **Back + LB + RB + A** (the base uses X and Y for
stats and graph) and keyboard **Ctrl+Alt+Shift+M**. While open, gamepad and keyboard input
is consumed, not forwarded. Items, each gated on permission bits where relevant:
`Server command: <name>` (one per command), `Push clipboard to PC`, `Pull clipboard from
PC`, `Toggle stats`, `Disconnect`, `Quit app on PC`. D-pad up/down moves, A activates,
B closes. On open, send an all-released gamepad state to the host (the way the quit chord
calls `LiSendMultiControllerEvent` with zeroed buttons) so nothing sticks while the menu
has the input; on close resume normal forwarding. On the Deck in Gaming Mode this must
render inside the SDL window; no new top-level windows.

### 6.4 Settings: new "Apollo host" GroupBox (column 1, after Host Settings)
| Preference | Type | Default | SER key |
|---|---|---|---|
| Client name | text | machine hostname | `apolloClientName` |
| Use virtual display by default | checkbox | on | `apolloVirtualDisplay` |
| Virtual display scale factor | combo 50/75/100/125/150/175/200 % | 100 | `apolloScaleFactor` |
| Clipboard sync | combo Off / Manual / Smart | Smart | `apolloClipboardSync` |
Tooltips explain each. Fractional fps is not exposed in M1; the millihertz path is
implemented and unit-tested at the HTTP layer only.

## 7. Build and dev loop

**macOS (this Mac: Apple Silicon, Xcode installed, Homebrew present, no Qt).**
`brew install qt` (Qt 6), then in the repo `python3 setup-deps.py` (downloads the
project's prebuilt macOS FFmpeg/SDL/opus bundle into `libs/mac`), then
`qmake6 moonlight-qt.pro && make -j`. Run the `.app`; screenshot with the computer-use
tools. Note the fork's `docs/macos-vrr-pyrowave.md` was written on an M5 Pro Mac, so the
Mac build is a maintained path. Ask the owner before the Homebrew install.

**Flatpak for the Deck.** Build in GitHub Actions by adapting `build-flatpak.yml`
(Docker is not running on the Mac). Fallback: `flatpak install --user org.flatpak.Builder`
on the Deck and run `flatpak-builder` as the `deck` user. Install with
`flatpak install --user ./DeckVoid-*.flatpak`, add as a non-Steam game, test in Gaming
Mode. Screenshots over SSH: `spectacle -b -o out.png` in Desktop Mode; in Gaming Mode use
Steam's screenshot and copy the file, or `gamescopectl` if the installed Gamescope
exposes a screenshot command (verify on device).

**Host.** The owner has a Vibepollo host on the LAN; ask for its address when integration
tests start. Pairing by OTP needs the owner to create the OTP in the web UI.

## 8. Rename and branding checklist (task 1)

- `app/app.pro`: `TARGET = deckvoid`; keep `version.txt` scheme but start at `0.1.0`.
- `app/main.cpp`: `setOrganizationName("DeckVoid")`, `setOrganizationDomain("oaa20203-source.github.io")`,
  `setApplicationName("DeckVoid")`, `setDesktopFileName("io.github.oaa20203_source.deckvoid")`.
  This moves QSettings to a new namespace so DeckVoid and stock Moonlight co-exist.
  Consequence to state in the README: hosts and pairings from stock Moonlight or the VRR
  build are not carried over; the user pairs again (an import is a possible M4 item).
- `app/deploy/linux/io.github.oaa20203_source.deckvoid.desktop` and `.appdata.xml`
  (Name=DeckVoid, Exec=deckvoid, Icon=deckvoid). Rename the icon resources.
- `packaging/flatpak/io.github.oaa20203_source.deckvoid.json`: app-id, `command: deckvoid`,
  `rename-icon`, module source pointing at the DeckVoid repo and commit, keep every other
  module (libplacebo, SDL3, SDL2-compat, SDL2_ttf, dav1d, ffmpeg, gamescope-wsi) unchanged.
- Workflows: keep `build.yml`, `build-flatpak.yml`, `build-appimage.yml`, `build-win-mac.yml`
  (macOS job only for now); delete `build-steamlink.yml` and `daily-prerelease.yml`;
  remove `github.repository == 'Nonary/...'` gates or point them at the new repo.
- `README.md`: new, short, with attribution to Moonlight, Nonary, Apollo/Artemis, VoidLink.
  Keep `LICENSE` (GPL-3.0) and keep Nonary's `AGENTS.md` and `architecture.md`.
- Submodule URL in `.gitmodules` to `oaa20203-source/moonlight-common-c`.

## 9. Testing strategy

Qt Test, same layout as `tests/power`. New subdir `tests/apollo` with its own `.pro`
compiling the production files it needs.

| Test | What it proves |
|---|---|
| `tst_apollohostinfo` | parses a recorded Vibepollo `/serverinfo` (write fixtures by hand from section 4.2; include one with `ServerCommand` entries, one plain-HTTP with `Permission=0`, one Sunshine response without the tags → `detected=false`) |
| `tst_apollopermissions` | bit helpers and names |
| `tst_nvapp_apollo` | applist parsing with `UUID`/`IDX`/`ArtVersion`, sort by index vs by name, notice app 114514 |
| `tst_launchurl` | `startApp` query string contains `appuuid`, `virtualDisplay`, `scaleFactor`, `clientName`; the `mode` formatter (a pure function taking fps in millihertz) yields `WxHx60` for 60000 and `WxHx59940` for 59940; `STREAM_CONFIGURATION.fps` is the rounded integer Hz; stock hosts get no Apollo params |
| `tst_otp` | `otpauth` equals uppercase hex SHA-256 of pin+salt+passphrase for a known vector; request contains `devicename`; no passphrase → no `otpauth` |
| `tst_clipboard` | loopback TLS server (reuse `tlsfixture.h`): GET returns body, POST sends `text/plain` with `uniqueid`/`uuid` present, 403 maps to a permission error |
| `tst_servercmd` (C) | `LiSendExecServerCmd` builds `{idx,0,0,0}` with type 0x3000 on channel 8, rejects when the control stream is not connected; table rows exist in all five tables |
| `tst_clipboardsync` | push on connect and focus gain, pull on focus loss, loop guard, Off/Manual/Smart |
Integration (manual, against the owner's Vibepollo host): OTP pair, app order, launch on
virtual and physical display with scale 150 %, server command visible and executed,
clipboard both ways, 403 message when a permission is revoked in the web UI. Then on the
Deck in Gaming Mode: quick menu renders and is navigable, no new windows.

## 10. Implementation plan (ordered; each task ends with passing tests and a checkpoint with the owner)

1. **Repository setup.** Fork Nonary/moonlight-qt at `v6.1.0-vrr18` into `oaa20203-source/deckvoid`
   with `upstream` remote; fork the common-c submodule; apply section 8; build on macOS;
   screenshot the unchanged UI with the new title. Checkpoint: owner sees "DeckVoid".
2. **Library packet.** In the common-c fork: `#define CTRL_CHANNEL_SERVERCTL 0x08`,
   `IDX_EXEC_SERVER_CMD` appended to the IDX list, `0x3000` in `packetTypesGen7` and
   `packetTypesGen7Enc`, `-1` in Gen3/4/5, `LiSendExecServerCmd(uint8_t)` mirroring the
   send-and-forget pattern, prototype in `Limelight.h`. Test `tst_servercmd`. Bump the
   submodule in the app repo.
3. **Host info and permissions.** `apollohostinfo.h`, `apollopermissions.h`; `NvComputer`
   field + `isApollo()` + `update()` + details text. Tests `tst_apollohostinfo`,
   `tst_apollopermissions`. Checkpoint: screenshot of View Details on a mock host.
4. **App identity and order.** `NvApp` fields, `getAppList` parsing, `sortAppList`, notice
   tile, resume-by-UUID in `Session::startConnectionAsync`. Test `tst_nvapp_apollo`.
5. **Launch options.** `apollolaunchoptions.h`, preferences (6.4) and SettingsView group,
   `startApp` changes, millihertz `mode`, `clientName`, 403 and 410 mapping in
   `verifyResponseStatus` callers, AppView context-menu items and driver-not-ready confirm.
   Test `tst_launchurl`. Checkpoint: screenshots of the settings group and the context menu.
6. **OTP pairing.** `NvPairingManager::pair` optional passphrase and `devicename`,
   `pairHostWithOtp`, PcView menu item and dialog. Test `tst_otp`. Checkpoint: dialog
   screenshot, then a live pairing against the owner's host.
7. **Clipboard.** `NvHTTP` get/set, `ClipboardSync`, preference, Session triggers: push on
   connect and focus gain, pull on focus loss and on disconnect **before** `LiStopConnection`
   (the host answers 403 once the stream has ended); loop guard; network calls off the
   render thread. Tests `tst_clipboard`, `tst_clipboardsync`.
8. **Quick menu v0.** Overlay list, chord and key combo, input capture while open, items
   wired to `Session::execServerCommand`, clipboard, stats, disconnect, quit. Checkpoint:
   screenshot on macOS, then on the Deck.
9. **CI and Flatpak.** Workflows trimmed and renamed; first Flatpak artifact installed on the
   Deck; Gaming Mode check of 6.3. Checkpoint: owner tests on the Deck.
10. **Integration pass** against the Vibepollo host (section 9), fix findings, tag `v0.1.0`.

## 11. Pitfalls (observed in the reference code; do not repeat)

- Artemis Qt stored fps×1000 in `STREAM_CONFIGURATION.fps`; it leaked into the SDP
  `maxFPS`, the pacer and bitrate defaults. Keep Hz internally; format mHz only in the URL.
- Artemis Qt applied `scaleFactor` on the client as well as sending it. Send only.
- Artemis Qt copied the pairing handshake and dropped the server-signature and
  challenge-hash checks, and logged the PIN and passphrase. Extend the existing manager.
- Artemis Qt probed guessed endpoints (`/servercommands`, `/api/commands`, ...) and fell
  back to a hardcoded command list whose indexes do not match the host. The only source of
  commands is `ServerCommand` in serverinfo.
- Artemis Qt's Quick Menu was a separate always-on-top `QQuickView`; Gamescope does not
  stack windows. Draw inside the SDL window.
- Artemis Qt's `Session` destructor deleted a QML-owned singleton. Own objects once.
- Artemis Qt's clipboard POST omitted `uniqueid`/`uuid`. Use `openConnection`.
- Control packet 0x3001 looks like clipboard but Vibepollo discards it.
- Do not report the Deck's built-in controller with the Steam Controller 2026 capability
  bits (grip, haptic, click); Vibepollo treats it as a plain pad (`src/platform/windows/vhf_gamepad_policy.h:107`).
  The base already handles `SDL_CONTROLLER_TYPE_STEAMDECK` correctly.
- VoidLink's library IDs 0x5504/0x5505, input magic 0x55000008 and capability 0x200 collide
  with Vibepollo's Steam Controller extensions. Never merge `voidlink-c`.

## 12. Later milestones (facts gathered; specs to be written when M1 ships)

**M2, Deck OLED performance and haptics (owner's top priority).**
- Panel: 1280x800, 90 Hz, no VRR on the internal display. Target 90 fps with the panel at
  90 Hz, fixed pacing (the base's VRR path is for external VRR displays). The base already
  shells out to `gamescopectl` (`app/streaming/gamescopecomposition.cpp`); extend it to set
  the refresh to match the stream fps.
- Codec: the Deck APU has no AV1 hardware decoder; HEVC Main10 via VAAPI gives the best
  quality per Mbps it can decode. Use Vibepollo's per-client "prefer 10-bit SDR". HDR
  through the base's HDR10 Vulkan swapchain under Gamescope.
- Known issue to investigate on device: Nonary's `docs/steamos-judder-20260910.md` and
  `docs/steamos-vrr.md` document Gaming-Mode judder that only cleared with Steam's
  performance overlay enabled; forced composition (`gamescopectl composite_force 1`) was the
  experiment. Reproduce on the owner's Deck first.
- Haptics: built-in pads rumble through Steam Input's rumble emulation (SDL rumble);
  DualSense paired to the Deck over Bluetooth gets Vibepollo waveform haptics (packet
  0x5601) which the base already renders on Linux. Expose intensity and a test button.
- Bitrate: implement client-side adaptive bitrate against Vibepollo's `GET /bitrate?bitrate=<kbps>`
  (`src/nvhttp.cpp:6961-7020`; `/api/abr/capabilities` says the host does none itself).
- Measure with the base's VRR trace tooling and `docs/stream-performance.md` before and after.

**M3, in-stream experience (VoidLink-derived).** Radial menu with stick selection and
A/B/X/Y hint HUD; Toolbox of editable key combos; game profiles (gyro to mouse or stick,
per-axis sensitivity, toggle/hold, dead zones, touch mode, pointer speed); settings
favourites panel; touch modes (passthrough, absolute, natural trackpad, relative, off,
split-screen hybrid); controller mouse mode; keyboard accessory bar; stats plots
(frametime, host frametime, queue depth, drops, decode time) and the network-vs-pacing
jitter split. All drawn inside the SDL window via ImGui on the Vulkan/libplacebo renderer.

**M4, Vibepollo extras.** Control tiles with the 410-as-success convention and
two-step Terminate (`src/remote_session.cpp:342-439`, `src/nvhttp.cpp:4931-5031`);
Remote Monitor (Deck as a second monitor) and Remote Input (video-less); hardware metrics
line in the HUD (`GET /api/hardware-metrics`, `docs/hardware-metrics.md`); `.art` files and
`art://` links for Steam shortcuts; `ArtVersion`-keyed box art cache.

## 13. Open questions and things to verify on device

- Does ClassicOldSong's Apollo (not Vibepollo) act on packet 0x3001? Irrelevant for M1
  (HTTPS clipboard works on both) but worth a note in the README.
- Gyro visibility to SDL under Gamescope with the default Steam Input layout.
- Whether `gamescopectl` is reachable from inside the Flatpak sandbox on the owner's
  SteamOS version (the base has a host-bridge fallback; confirm it works).
- The exact Nonary tag to pin: `v6.1.0-vrr18` is the tested release; master is ahead
  (`version.txt` 6.2.0). Pin the tag unless a needed fix is only on master.

## 14. Definition of done for milestone 1

All tests in section 9 pass in CI. Against the owner's Vibepollo host: OTP pairing works
from the Deck; apps appear in host order; an app launches on the virtual display at
150 % scale and on the physical display with the warning shown; a server command runs;
clipboard syncs both ways; revoking "Launch" in the web UI produces the permission
message. Sunshine hosts behave exactly as before. The owner has seen and approved
screenshots of every screen in section 6 on macOS and on the Deck.
