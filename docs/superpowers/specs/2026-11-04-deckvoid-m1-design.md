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
you can: pair with a PIN and passphrase created on the host via `POST /api/otp` (section 4.7)
without touching the PC; see the apps in the order the host owner arranged; launch an app on a virtual
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
  app/streaming/session.*         execServerCommand, clipboard triggers, quick menu v0,
                                  constructor override for the per-launch virtual display
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
| `Permission` | paired HTTPS only; plain HTTP (unpaired host) always reports `0`, which means "unknown", not "no permissions". Read it only from an HTTPS serverinfo response | decimal bitmask, section 4.3 (`:4319-4322`) |
| `ServerCommand` (repeated) | paired HTTPS and `server_cmd` bit | command names; **list position = index for packet 0x3000** (`:4304-4317`) |
| `VirtualDisplayCapable`, `VirtualDisplayDriverReady`, `VirtualDisplayHDRCapable` | always | strings `true`/`false` (`:4277-4294`) |
| `currentgameuuid` | always | UUID of the running app when exposed to this caller (see multi-client note), else empty (`:4426-4430`) |
| `currentgame`, `state`, `appversion`, `GfeVersion`, `HttpsPort`, `ExternalPort`, `mac`, `ServerCodecModeSupport` | stock | already parsed by the base |
| `FrameLimiter*`, `PowerActionVersion`, `Sleep*`, `PyroWave*`, `HardwareMetricsVersion` | Vibepollo | already parsed or M4 |

Multi-client note: `currentgame=0` / empty `currentgameuuid` / `SUNSHINE_SERVER_FREE` does
not mean nothing is running. The running game is reported (BUSY) only to the client that
owns it, and only if (a) that client does not itself hold a Remote Input or Remote Monitor
role, and (b) `enable_input_only_mode` is off or the running app is the input-only app.
Exception: a non-owner sees it while an app-replacement confirmation is armed for that
client (`src/nvhttp.cpp:4401-4436`, `src/remote_session.cpp:271-281`). Use `/applist` for
non-owners instead. It puts a synthetic running-game tile and Resume and Terminate control
tiles at the front of the list, and a client holding the Remote Monitor role gets only
Resume and Disconnect-Monitor tiles (`src/remote_session.cpp:284-334`).

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

A newly paired client gets `view | list` (`PERM::_default`, `src/crypto.h:74`). The
exception is when no other device is currently paired: that client gets all permissions
(`_all`, `src/nvhttp.cpp:3719-3729`). A re-pair whose certificate matches an existing entry
keeps that entry's permissions (`:2739-2775`). DeckVoid has a new certificate, so it always
creates a new entry. The owner's host already has paired clients, so DeckVoid starts
without `launch`, `server_cmd`, `clipboard_set` or `clipboard_read`: launches return 403
(4.5), clipboard calls return 401 (4.9) and serverinfo lists no `ServerCommand` (4.2) until
the owner grants them. There is no separate "terminate" bit; `launch` covers quit
(`src/nvhttp.cpp:4689-4691`).

### 4.4 `/applist` (`src/nvhttp.cpp:4617-4777`, Apollo)
Each `<App>` carries `UUID`, `IDX`, `ArtVersion` in addition to `ID`, `AppTitle`,
`IsHdrSupported`. The host returns the real list when the client has any one of `list`,
`view` or `launch`: `src/nvhttp.cpp:4637` tests `has_client_perm(..., PERM::_all_actions)`,
and that check passes when any bit in the mask is set (`:3781`). Only a client with none of
the three gets a single notice app instead (`:4762-4775`). The notice has `ID=114514`, an
empty `UUID`, `IDX=0`, `IsHdrSupported=0`, and an `AppTitle` telling the user to enable
"List applications" for the device in the host's web UI.

Vibepollo adds synthetic "control tiles". Identify them by UUID, never by numeric ID: they
are `9a1c5a25-58fe-40e0-b9aa-7d3f0000000N` for N = 1-7, in this order: Resume, Disconnect
Monitor, Disconnect Input, Terminate, Remote Monitor, Remote Input, running-game copy
(`src/remote_session.cpp:57-63,145-148`). Compare them case-insensitively; the host emits
lowercase. For reference only, the numeric IDs are as follows. Primary tiles use
2147483501-2147483506. Tiles shown to a secondary (non-owner) client while a game runs use
2147483511 (Resume), 2147483514 (Terminate), 2147483515 (Remote Monitor) and 2147483516
(Remote Input) (`src/remote_session.h:18-31`). The host still routes the old cached IDs
2147483601-2147483606 but no longer lists them. The running-game tile shown to non-owners
does not use 2147483507. Its ID is `(app_id & 0x7fffffff) ^ 0x40000000`, probed upward past
collisions (`:162-186`), so it can be any positive value. Secondary and running-game tile
titles start with leading spaces that the host uses to rank them; trim them for display.
In M1 these tiles are shown as ordinary apps; M4 handles them properly.

### 4.5 `/launch` and `/resume` (`src/nvhttp.cpp:3053-3493`, Apollo unless noted)
Required by the host: `rikey`, `rikeyid`, `localAudioPlayMode`, and `appid` or `appuuid`;
the TLS client certificate must be paired (`:4816-4835`).

Add to the base's query string:
| Parameter | Value | Notes |
|---|---|---|
| `appuuid` | app UUID | identity resolved by UUID first (`:3288-3297`); keep sending `appid` for Sunshine. Omit the parameter when the app's UUID is empty (notice tile, stock Sunshine). |
| `mode` | `WxHxR` | `R` may be an integer Hz, a decimal with up to 3 fractional digits (`59.94`), or millihertz if 1000 or more (`59940`). Range 10000-1000000 mHz (`:3154-3241`). Fallback on parse failure is 1920x1080x60. |
| `virtualDisplay` | `0` or `1`, or omitted | Omit it when the preference is Host decides (-1, section 6.4): the host then applies its own per-client `always_use_virtual_display`, `output_name` override, per-app `virtual_display` and global `virtual_display_mode`. When present, it overrides all of those (`src/session_display_policy.h:37-58`, `src/nvhttp.cpp:1479-1488`, `:3302-3307`): `1` forces a virtual display even for apps the host configured as physical; `0` forces physical, disables the host's global virtual-display mode for that launch, and yields `<clientWarning>virtual_display_disabled_by_client</clientWarning>` in a successful reply (`:2955-3008`), which the base already parses (`app/backend/launchwarning.h`). The stock Launch/Resume items send the preference value (omitting the parameter when it is -1). The context-menu items always send an explicit `1` or `0`. |
| `scaleFactor` | 20-200, default 100 | scales the host virtual display, stream resolution unchanged (`:3422-3465`). Do **not** also scale on the client. |
| `clientName` | string | only applied if the paired record has no name (`:3102-3109`) |
| `clientVrrRequested` | `1` | Vibepollo; the base already sends it |

Reply fields: `sessionUrl0`, `gamesession=1` (or `resume=1`), `VirtualDisplayDriverReady`,
`clientWarning`.

Status codes are the XML `root@status_code` / `root@status_message` attributes in the reply
body, not HTTP status codes (`src/nvhttp.cpp:4798-4807`); the base throws
`GfeHttpResponseException` for any value other than 200 (`app/backend/nvhttp.cpp:519-538`).
Each comes with a `status_message`:
- **400.**
- **403**: permission. The message already names the missing permission and where to
  enable it in the web UI (`:3888-3899`).
- **404.**
- **409**: conflict, including "Remote Input or Remote Monitor is active".
- **410** (Vibepollo): the action succeeded and no stream follows. It is not an error: show
  `status_message` to the user, do not start a stream, and do not report a launch failure.
  The host returns it (a) for app-replacement confirmation, which is on by default
  (`remote_monitor_confirm_app_replacement`, `src/config.cpp:942`; `src/nvhttp.cpp:5398-5416`):
  launching a different app while one runs gets a 410 prompt, and repeating the same
  `/launch` within 60 s confirms it, after which the host quits the old app itself
  (`:5432-5433`), so the client must not send `/cancel` first; (b) for the Terminate control
  tile's two-step confirmation (`:4931-4950`); (c) for the legacy Terminate app
  `E16CBE1B-295D-4632-9A76-EC4180C857D3` ("App terminated."), which is listed when
  input-only mode is on and an app is running (`:4640-4643`, reply at `:5368-5377`). M1
  must map 410 to an informational message, because control tiles are visible in M1 (4.4)
  and replacement prompts happen on ordinary launches; M4 only adds the dedicated
  control-tile UI.
- **500.**
- **503**: several causes, not all transient. `/resume` answers 503 "No running app to
  resume" when the app exited after the last poll (`:6012-6016`); other 503s report a
  missing driver capability or a display that could not be woken.

### 4.6 Every request
Base `openConnection` already appends `uniqueid=<client id>&uuid=<random>`. In
`NvPairingManager::pair`, replace the hard-coded `devicename=roth` (`nvpairingmanager.cpp:235`,
and the same string at `:269`, `:300`, `:347`, `:360`) with the URL-encoded Client name
preference (6.4), for all host types (Artemis does the same, `NvHTTP.java:478`). Do not add
a second `devicename`: the host's argument map is a case-insensitive multimap
(`src/nvhttp.h:37`), and `get_arg` (`src/nvhttp.cpp:2276`) takes whichever copy `find`
returns. The host reads the name only on `phrase=getservercert` (`src/nvhttp.cpp:4014-4040`)
and maps `roth` to "Legacy Moonlight Client" (`:4033-4037`). It refuses to pair a client
named `self`, compared case-insensitively after trimming (`:2906-2909`, `:3702-3706`), so
never send that name. With OTP pairing, the device name the owner gave when creating the
OTP (4.7) replaces the client's name (`:4066-4068`).

### 4.7 OTP pairing (`src/nvhttp.cpp:4054-4082`, Apollo)
Host side: the owner chooses a passphrase (min 4 chars) and an optional device name and
calls the authenticated `POST /api/otp` (JSON `{passphrase, deviceName}`,
`src/confighttp.cpp:5030-5056`). The host generates the 4-digit PIN (`nvhttp::request_otp`,
`src/nvhttp.cpp:7712-7722`) and returns it as `otp`. It stays valid for 180 s. Neither
shipped web UI in 2.0.6 calls this endpoint; the unbuilt `pin.html` in `src_assets` is not
served.
Client side: on the first pairing request (`phrase=getservercert`) add
```
otpauth=<uppercase hex of SHA-256( pin + saltHex + passphrase )>
```
where `saltHex` is the same `salt=` value sent in that request (16 random bytes, hex).
The user-entered PIN replaces the client-generated one. Everything else in the pairing
handshake is unchanged.

Failure behaviour: if the hash mismatches, no OTP is active, or the OTP is older than
180 s, the host still answers `getservercert` positively (status_code 200, `paired=1`, a
`plaincert`) using a random PIN (`:4055-4081`). In the no-OTP and expired cases it first
sets 503 "OTP auth not available." (`:4056-4062`), but `getservercert` then overwrites the
code with 200 (`:4079`, `:3562-3584`); only `status_message` still reads "OTP auth not
available.". No 503 reaches the client. The base `verifyResponseStatus` checks only the
code, so pairing continues and fails at the PIN-hash check after `serverchallengeresp`
(`nvpairingmanager.cpp:330-339`) with `PairState::PIN_WRONG`, exactly like a wrong hash. A
wrong hash does not consume the OTP, so the user can retry within the 180 s; a matching
hash consumes it, so a second attempt with the same PIN finds no OTP. Without further
checks the client cannot tell these cases apart. Optionally, check `status_message` on the
`getservercert` reply for "OTP auth not available" and stop early with an "OTP expired or
not created" error. Reference: Artemis `PairingManager.java:212-226`.

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
`GET  /actions/clipboard?type=text` returns the host clipboard as a plain-text body (`src/nvhttp.cpp:6860-6903`).
`POST /actions/clipboard?type=text` with a `text/plain` body sets it (`:6905-6959`).
Both need HTTPS with the pinned certificate. The host answers with bare HTTP status codes
and no XML `status_code`, so do not run `verifyResponseStatus` on these replies. Status
codes (`:6864-6872`/`:6910-6918`, `:6892-6897`/`:6938-6943`):
- **401**: missing permission. The client needs View or Launch (`_allow_view`; the check
  passes when any bit of the mask is set, `:3781-3783`), plus `clipboard_read` for GET or
  `clipboard_set` for POST.
- **403**: no active stream from this certificate. Not a permission problem; expected once
  the stream has ended.
- **400**: `type` other than `text`.
- **500**: the host failed to set the clipboard.

Read the HTTP status code from the reply (Qt reports 401 as `AuthenticationRequiredError`
and 403 as `ContentAccessDenied`); do not rely on the error text. Reference: Artemis
`NvHTTP.java:922-937`.

### 4.10 Remote Input (input-only) app
On Vibepollo the "Remote Input" entry in `/applist` is a synthetic control tile (see 4.4).
Its UUID is `9a1c5a25-58fe-40e0-b9aa-7d3f00000006`. Its ID is 2147483506, or 2147483516 when
another client's game is running, in which case the title is padded with leading spaces
(`src/remote_session.cpp:62,76-80,157,307-338`). It is listed whether or not
`enable_input_only_mode` is set. The only exception: if the host admin removes it, it
disappears, except for a client that already holds the input role
(`src/nvhttp.cpp:4709-4716`). Identify it by UUID, not ID. The legacy Apollo UUID
`8CB5C136-DA67-4F99-B4A1-F9CD35005CF4` (`src/legacy_generated_app_identities.h:9`) is never
listed: `/applist` marks it not visible (`src/nvhttp.cpp:4673-4676`,
`src/remote_session.cpp:290-299`). The host accepts it at `/launch` only when
`enable_input_only_mode` is on (`src/nvhttp.cpp:5339`).

M1 behaviour: launching the Remote Input entry (control-tile UUID, or the legacy UUID if a
host ever lists it) must not quit a running game. With `enable_input_only_mode` on and a
real game running this already holds: the host reports `currentgame=0` and
`currentgameuuid=""` to everyone (`:4426-4431`), so the client sends `launch`. The reverse
is not safe by default: while Remote Input runs, the owner sees it as `currentgame`, so
picking a real game must send `launch` with no quit prompt (task 4). Full video-less
sessions are M4.

## 5. Hook map in the base (Nonary/moonlight-qt master `76ee5025`)

Line numbers drift; search for the function names.

| Purpose | Location |
|---|---|
| `/serverinfo` parsing | `NvComputer::NvComputer(NvHTTP&, QString serverInfo)` `app/backend/nvcomputer.cpp:132-231`; style examples `FrameLimiterCapabilities::fromServerInfo` (`framelimitercapabilities.h:9-33`), `PowerActions::advertised` (`poweractions.h:40-49`) |
| `NvComputer` fields and `update()` | `nvcomputer.h:21-129`; `ASSIGN_IF_CHANGED` macros `nvcomputer.cpp:547-560`, fork fields at `:580-586` |
| Serialization | `SER_*` `nvcomputer.cpp:12-26`, `serialize()` `:79-106`, `isEqualSerialized()` `:110-123` (see the reminder at `nvcomputer.h:126`); `NvApp` keys `nvapp.cpp:3-8`, `NvApp::serialize` `nvapp.cpp:20-28`, `NvApp::operator==` `nvapp.h:11-19` |
| App sorting | `NvComputer::sortAppList()` `nvcomputer.cpp:125-130`, called at `:54` (QSettings constructor, before any `/serverinfo`) and `:498`; `updateAppList` `:482-500` returns early when `appList == newAppList` |
| App list fetch | `NvHTTP::getAppList()` `nvhttp.cpp:455-505` |
| Launch URL | `NvHTTP::startApp(...)` `nvhttp.cpp:343-401`; query block `:363-392`; `LaunchWarning::parse` at `:400` |
| HTTP plumbing | `openConnection` `nvhttp.cpp:661-865` (uniqueid/uuid at `:684-686`; power requests skip them); `openConnectionToString` `:637-659`; `verifyResponseStatus` `:507-544`; `GfeHttpResponseException` `nvhttp.h:35-68`. `openConnection` always POSTs an empty body (`:765-766`), sets Content-Type only for power requests (`:688-692`), and drops the HTTP status on non-power errors (`:850-865`; only the pyrowave probe at `:812-823` and power paths keep `HttpStatusCodeAttribute`). |
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
| Overlay API | `video/overlaymanager.h:17-80` (`OverlayDebug`, `OverlayStatusUpdate`, `setStatusMessage`, renderer pull model); per-type colors and font sizes `overlaymanager.cpp:375-379`; per-renderer positioning: `plvk.cpp:2591`, `eglvid.cpp:207`, `vaapi.cpp:756`, `vt_metal.mm:598`, `vt_avsamplelayer.mm:413`, `drm.cpp:1568`, `sdlvid.cpp:237`, `vdpau.cpp:446`, `d3d11va.cpp:1712`, `dxva2.cpp:661`, `slvid.cpp:177` |
| Control stream packet tables | `moonlight-common-c/src/ControlStream.c:143-157` IDX list, tables `:165-249` (five tables; Gen7Enc `:233-249`), `sendMessageAndForget` `:882`, send-and-forget example `confirmLongtermReferenceFrame` `:1703-1720`; public prototypes `Limelight.h` near `:1215` |
| Tests | `tests/tests.pro` (subdirs, opt-in with `CONFIG+=tests`); example `tests/power/poweractions.pro`, `tst_poweractions.cpp`, loopback TLS `tlsfixture.h`; README in `tests/power` |
| Branding | `app/app.pro:5-8` TARGET, `:38-42` version, `:719-728` Linux INSTALLS; `app/resources.qrc`; `app/main.cpp:464-471` names, `:1003` desktop file; `app/deploy/linux/*.desktop` and `.appdata.xml`; `packaging/flatpak/com.moonlight_stream.Moonlight.json`; `.github/workflows/build-flatpak.yml`, `build-release.yml`; `.github/ISSUE_TEMPLATE/bug_report.md` |
| CI | `build.yml` (tests + calls), `build-appimage.yml`, `build-flatpak.yml`, `build-win-mac.yml`, `build-steamlink.yml`, `build-release.yml`, `daily-prerelease.yml` (gated on `github.repository == 'Nonary/moonlight-qt'`) |

## 6. Milestone 1 user interface (owner to review)

Build the macOS dev binary and screenshot each of these for the owner before moving on.

### 6.1 Pairing
- PC context menu gains **"Pair with PIN and passphrase..."** under the existing items,
  shown only for unpaired hosts where `isApollo()` is true (detection works over plain HTTP
  via `VirtualDisplayCapable`). GFE and stock Sunshine ignore `otpauth`, so the item is
  hidden for them. The existing click-to-pair flow is unchanged.
- Dialog (a `NavigableDialog`): two fields, PIN (4 digits, numeric) and passphrase
  (masked, min 4 chars), buttons Pair / Cancel, and this text: "On the host, create a
  one-time PIN: send an authenticated POST to https://<host>:47990/api/otp with
  Content-Type: application/json and body {"passphrase":"<at least 4 chars>","deviceName":"<name>"}.
  Use the web UI admin login. Vibepollo 2.0.6's web UI has no OTP page. Then enter the
  4-digit "otp" value from the response and the same passphrase here within 3 minutes."
  On success the dialog closes and the host shows as paired. On failure the existing error
  dialog is shown. In the OTP flow, use this text for `PIN_WRONG` instead of the plain
  `PairState` text: "Pairing failed: the PIN or passphrase is wrong, or the PIN expired
  (3 minutes) or was already used. Generate a new PIN on the host and try again." If the
  optional early check in 4.7 is implemented, show its "OTP expired or not created" error
  instead. Keep the base texts for `FAILED` and `ALREADY_IN_PROGRESS`
  (`computermanager.cpp:604-617`).
- "View Details" gains a **Permissions** block listing the human names of granted bits
  when the host is Apollo and paired. For an unpaired Apollo host it shows "Permissions:
  pair to see".

### 6.2 App grid
- Apps ordered by host `IDX` on Apollo hosts. `IDX` is a string. Sort key: `IDX` parsed as
  a non-negative integer, ascending. Configured apps carry their 0-based position
  (`src/process.cpp:4930-4969`). Synthetic control tiles carry their numeric ID as `IDX`
  (`src/nvhttp.cpp:4748`; ID ranges in 4.4), so most sort after the configured apps; the
  running-game copy's ID can be any positive value. Entries with an empty or non-numeric
  `IDX` (a catalogue entry with no configured app) go after all numbered entries. Ties keep
  XML order (use `std::stable_sort`; the host emits the XML in its projection order,
  `:4732`). Never parse `IDX` with a throwing or zero-defaulting conversion. Use
  `toUInt(&ok)` and treat `!ok` as "unnumbered". Persist `IDX` (and `UUID`) in new `NvApp`
  SER keys so `sortAppList()`, which also runs on the cached list in the
  `NvComputer(QSettings&)` constructor (`app/backend/nvcomputer.cpp:54`), keeps host order
  offline. That constructor sorts before any `/serverinfo`, so `sortAppList()` cannot test
  `isApollo()`: use host order when at least one app has a numeric `IDX`, otherwise the
  base's case-insensitive name sort, which non-Apollo hosts keep.
- If the host's global "legacy ordering" option is on (default off, `src/config.cpp:1125`)
  and the client's per-device "Enable legacy ordering" flag is on (default on for new
  clients, `:3731`), the host prefixes each `AppTitle` with a run of U+200B/U+200C
  characters (`:4719-4741`, `src/zwpad.h`). When `isApollo()`, strip leading U+200B/U+200C
  from `AppTitle` at parse time so name display, name sort and search see the real title.
- The ID 114514 notice app renders as a non-launchable tile with the host's message.
- Context menu on an app, when the host is Apollo and virtual display is capable:
  **"Launch on virtual display"** / **"Launch on physical display"** (when the preference
  is Host decides, show both; otherwise show the one that differs from the preference) in
  addition to the stock Launch/Resume. If the driver is not ready
  (`VirtualDisplayDriverReady=false`) show a confirm dialog and allow proceeding.
- Launch / Resume / Launch on virtual or physical display stay visible regardless of the
  `launch` bit; a 403 from the host is shown as the permission message (section 14 depends
  on this).

### 6.3 Quick menu v0 (in-stream)
A minimal, gamepad-navigable text list drawn through the overlay system, seed of the M3
radial menu. The overlay system has only two fixed slots (`OverlayDebug` top-left,
`OverlayStatusUpdate` bottom-left; `overlaymanager.h:17-21`). Each slot holds one text
surface with one color, one font size and a 1024-char buffer (`overlaymanager.h:85-97`).
Do not reuse `OverlayDebug`: it is gated by the stats toggle and chords
(`overlaymanager.cpp:640`, `gamepad.cpp:386-399`, `keyboard.cpp:52-58`), which clash with
the menu's own `Toggle stats` item. Instead, add `OverlayQuickMenu` before `OverlayMax`.
Give it a color and font size in the `OverlayManager` constructor
(`overlaymanager.cpp:375-379`; otherwise fontSize is 0). Add a position branch for it
(centered is suggested) in every renderer that switches on overlay type. At minimum that
means `plvk.cpp:2591-2600` (otherwise it draws at 0,0 over the stats), `eglvid.cpp:207-217`
(otherwise it hits `SDL_assert(false)`) and `vaapi.cpp:756` for the Deck, plus
`vt_metal.mm:598` and `vt_avsamplelayer.mm:413` for the macOS dev build. Also check
`drm.cpp:379`/`:1568` (a third type needs a third plane or falls back to composition mode),
`sdlvid.cpp:237`, `vdpau.cpp:446`, `d3d11va.cpp:1712`, `dxva2.cpp:661` and `slvid.cpp:177`.
A slot has a single color, so mark the selection with a text marker (`> ` before the
selected line), rewrite the text on every selection change, and keep the whole menu text
under 1024 chars, truncating server command names if needed.

Opened with gamepad chord **Back + LB + RB + A** (the base uses X and Y for stats and graph)
and keyboard **Ctrl+Alt+Shift+O**. M is already the base's mouse-mode toggle
(`KeyComboToggleMouseMode`, `input.cpp:99-102`); letters still free in the base: a b g h i
j n o p r t u w y. Add `KeyComboQuickMenu` to the `KeyCombo` enum in
`app/streaming/input/input.h` just before `KeyComboMax`. Register it in the
`SdlInputHandler` constructor in `input.cpp` next to the other `m_SpecialKeyCombos` entries
(keyCode `SDLK_o`, scanCode `SDL_SCANCODE_O`, enabled=true), and handle it in
`performSpecialKeyCombo` (`keyboard.cpp`).

While the menu is open, Session consumes all input and does not forward it to the host.
This covers keyboard, gamepad buttons and axes, controller touchpad and motion-sensor
events, mouse button/motion/wheel events (including Deck trackpads mapped to the mouse),
and touch-screen finger events. The stats and graph chords and their keyboard shortcuts
are inactive while the menu is open.

Items: `Server command: <name>` (one per command), `Push clipboard to PC`, `Pull clipboard
from PC`, `Toggle stats`, `Disconnect`, `Quit app on PC`. Gating: `Server command: <name>`
items appear only when `server_cmd` is granted and the host sent at least one
`ServerCommand`; Push needs `clipboard_set`; Pull needs `clipboard_read`; Quit app on PC
needs `launch`; Toggle stats and Disconnect are always shown. Items whose bit is missing are
hidden, not disabled. D-pad up/down moves, A activates, B closes. On open, send an
all-released gamepad state to the host (the way the quit chord calls
`LiSendMultiControllerEvent` with zeroed buttons) so nothing sticks while the menu has the
input; on close resume normal forwarding. On the Deck in Gaming Mode this must render
inside the SDL window; no new top-level windows.

### 6.4 Settings: new "Apollo host" GroupBox (column 1, after Host Settings)
| Preference | Type | Default | SER key |
|---|---|---|---|
| Client name | text | machine hostname | `apolloClientName` |
| Display for launches | combo Host decides / Virtual display / Physical display | Host decides | `apolloVirtualDisplay` (int: -1 / 1 / 0) |
| Virtual display scale factor | combo 50/75/100/125/150/175/200 % | 100 | `apolloScaleFactor` |
| Clipboard sync | combo Off / Manual / Smart | Smart | `apolloClipboardSync` |

Tooltips explain each. The "Display for launches" tooltip: "Host decides leaves the choice
to the host's per-app and per-client settings. Virtual or Physical overrides them for every
launch from this client." Fractional fps is not exposed in M1; the millihertz path is
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
tests start. Pairing by OTP needs the owner to create the OTP via `POST /api/otp` (4.7).
After the first OTP pairing, ask the owner to grant DeckVoid Launch, Run server commands,
Read clipboard and Set clipboard in the web UI's client management page (new clients get
only View and List while another device is paired, 4.3). Do this before any section 14
integration step except pairing and app order.

## 8. Rename and branding checklist (task 1)

- `app/app.pro:4-9`: `TARGET = deckvoid` in the `unix:!macx` branch (line 5) and
  `TARGET = DeckVoid` in the macOS branch (line 8). Change the Linux INSTALLS rules
  (`:719-728`) to the renamed files: `desktop.files` (line 719), `icons.files` (line 722,
  `res/deckvoid.svg`) and `appstream.files` (line 725). Otherwise `make install` fails
  inside flatpak-builder (and in an AppImage build). Keep the `version.txt` scheme but
  start at `0.1.0`.
- `app/main.cpp`: `setOrganizationName("DeckVoid")`, `setOrganizationDomain("oaa20203-source.github.io")`,
  `setApplicationName("DeckVoid")`. At line 1003 use
  `setDesktopFileName("io.github.oaa20203_source.deckvoid")`, and at lines 1004-1005 set
  `SDL_VIDEO_WAYLAND_WMCLASS` and `SDL_VIDEO_X11_WMCLASS` to the same ID; otherwise the
  stream window matches stock Moonlight's desktop entry and icon. At lines 775-776 set
  `SDL_HINT_AUDIO_DEVICE_APP_NAME` and `SDL_HINT_APP_NAME` to `"DeckVoid"`. The new
  organization and application names move QSettings to a new namespace, so DeckVoid and
  stock Moonlight co-exist.
- Consequence to state in the README: hosts and pairings from stock Moonlight or the VRR
  build are not carried over, and the user pairs again (an import is a possible M4 item).
  Pairing creates a new device entry on the host. If another device is already paired, the
  new entry starts with View and List only. Before DeckVoid can launch apps, sync the
  clipboard or run server commands, open the host web UI and grant the DeckVoid device
  Launch, and Clipboard and Server commands if wanted. The old Moonlight entry stays valid
  until you remove it in the web UI. On the Deck, the separate Flatpak app ID already keeps
  DeckVoid's data apart (`~/.var/app/io.github.oaa20203_source.deckvoid`). The QSettings
  rename matters for macOS and AppImage builds. Nonary's and Flathub's Moonlight both use
  `com.moonlight_stream.Moonlight`, so an M4 import would need
  `--filesystem=~/.var/app/com.moonlight_stream.Moonlight:ro`.
- Icon: rename `app/res/moonlight.svg` to `app/res/deckvoid.svg` and update every
  reference: `app/resources.qrc:22`, `app/main.cpp:999` (`setWindowIcon`),
  `app/streaming/session.cpp:2198` (`QSvgRenderer`) and `scripts/generate-ico.sh`.
- `app/deploy/linux/io.github.oaa20203_source.deckvoid.desktop` and
  `io.github.oaa20203_source.deckvoid.appdata.xml` (Name=DeckVoid, Exec=deckvoid,
  Icon=deckvoid). In the AppStream file set `<id>io.github.oaa20203_source.deckvoid</id>`
  and `<launchable type="desktop-id">io.github.oaa20203_source.deckvoid.desktop</launchable>`,
  and replace the name, summary, moonlight-stream URLs, developer and update_contact.
- macOS: in `app/Info.plist:16` set `CFBundleIdentifier` to
  `io.github.oaa20203-source.deckvoid` (hyphen, because bundle IDs do not allow
  underscores) and set the bundle name to DeckVoid. In `scripts/generate-dmg.sh` (lines
  61-102) replace every `Moonlight.app` and `Contents/MacOS/Moonlight` with `DeckVoid.app`
  and `Contents/MacOS/DeckVoid`, and rename the dSYM and DMG outputs to DeckVoid. This keeps
  the Mac dev build from sharing a bundle ID with an installed stock Moonlight.
- `packaging/flatpak/io.github.oaa20203_source.deckvoid.json`: set `app-id`,
  `command: deckvoid` and `rename-icon: deckvoid`; `rename-icon` must equal the basename of
  the installed icon. Point the module source at the DeckVoid repo and commit (the base
  manifest pins `https://github.com/nonary/moonlight-qt.git` commit `35fdcb0e`). Rename the
  `moonlight` module to `deckvoid`, and replace or drop its `shell` source
  `echo 6.1.0-vrr13 > app/version.txt`, which would otherwise overwrite DeckVoid's `0.1.0`
  `version.txt`. Keep every other module unchanged: libplacebo with its patch, libdecor,
  SDL3, SDL2-compat, SDL2_ttf, dav1d, ffmpeg and gamescope-wsi.
- `packaging/flatpak/README.md`: change the manifest path, the app ID, the branch and the
  bundle filename (`DeckVoid-<version>-linux-x86_64.flatpak`) in the build and install
  commands.
- `app/backend/autoupdatechecker.cpp:135-137,341`: this checker runs on Windows, macOS,
  AppImage and Steam Link builds (not Flatpak) and checks Nonary's releases. Point it at
  `https://api.github.com/repos/oaa20203-source/deckvoid/releases`, set User-Agent
  `DeckVoid-UpdateChecker`, and change the release-page link to the DeckVoid repo, or
  disable `start()` until DeckVoid's first release. Update
  `tests/updates/tst_autoupdatechecker.cpp` (for example the Nonary URL assertion at
  `:307`) to match.
- Workflows: keep only `build.yml` and `build-flatpak.yml`. Delete `build-win-mac.yml`,
  `build-appimage.yml`, `build-steamlink.yml`, `build-release.yml` (its inline Flatpak job
  had the same hard-coded names) and `daily-prerelease.yml`, and remove
  `.github/dependabot.yml`. In the same commit, delete the jobs in `build.yml` that call the
  deleted files (for example `build-steamlink`, base lines 66-70), or the Build workflow
  fails because the file it calls is gone. Remove the `github.repository == 'Nonary/...'`
  gates or point them at the new repo.
  - `daily-prerelease.yml` was the only caller of `build-flatpak.yml`, so add a
    `build-flatpak` job to `build.yml` (`needs: setup`,
    `ci_version: ${{ needs.setup.outputs.ci_version }}`, `source_ref: ${{ github.sha }}`).
    It can also be run by hand through its `workflow_dispatch` trigger.
  - In `build-flatpak.yml`: change the manifest path (base lines 76, 108) to
    `packaging/flatpak/io.github.oaa20203_source.deckvoid.json`; change the
    `m['name'] == 'moonlight'` / `modules['moonlight']` lookups to `deckvoid`; change the app
    ID `com.moonlight_stream.Moonlight` (base lines 110, 130-133, 144, including the
    `//master` refs in the build-bundle, `flatpak info` and `flatpak run` lines) to
    `io.github.oaa20203_source.deckvoid`; rename the bundle and artifact from
    `Moonlight-$CI_VERSION` to `DeckVoid-$CI_VERSION`; change `files/bin/moonlight` to
    `files/bin/deckvoid`; change the `--version` checks to `grep -Fx "DeckVoid $CI_VERSION"`;
    and replace the `6\.[12]\.0-daily\.N` assertion (base line 86) with one that accepts
    DeckVoid's versions: `0.1.0`-style releases and the CI version `build.yml` passes.
  - `scripts/verify-linux-features.py:13` (run in the Flatpak post-install): change
    `usr/bin/moonlight` and `bin/moonlight` to `deckvoid`.
  - The base runs the `tests/tests.pro` tree in no CI job: only the Windows job built it,
    and only with nmake. Add a Qt test job to `build.yml` (ubuntu-latest,
    `apt-get install qt6-base-dev libssl-dev`, or install-qt-action) that runs
    `qmake6 tests/tests.pro CONFIG+=tests && make -j && make check`.
- `README.md`: new, short, with attribution to Moonlight, Nonary, Apollo/Artemis, VoidLink.
  Keep `LICENSE` (GPL-3.0) and keep Nonary's `AGENTS.md` and `architecture.md`.
- Submodule URL in `.gitmodules` to `oaa20203-source/moonlight-common-c`.

## 9. Testing strategy

Qt Test, same layout as `tests/power`. The Qt tests live in `tests/apollo`: one
`apollo.pro` (`CONFIG += testcase`, as `tests/power/poweractions.pro` does) compiles the
production files it needs and builds `tst_apollo`. It is registered in the
`contains(CONFIG, tests)` block of `tests/tests.pro` (`apollo.file = $$PWD/apollo/apollo.pro`,
`SUBDIRS += apollo`); otherwise the Qt tests never build. The `tst_*` names below are test
groups; give one its own `.pro` under `tests/apollo` only if it needs different production
sources, and register that `.pro` in the same block. `tst_servercmd` is the exception: it is
C and lives in the common-c fork.

| Test | What it proves |
|---|---|
| `tst_apollohostinfo` | parses a recorded Vibepollo `/serverinfo` (write fixtures by hand from section 4.2; include one with `ServerCommand` entries, one plain-HTTP with `Permission=0`, one Sunshine response without the tags → `detected=false`) |
| `tst_apollopermissions` | bit helpers and names |
| `tst_nvapp_apollo` | applist parsing with `UUID`/`IDX`/`ArtVersion`; sort by index vs by name: IDX values "2", "10", "", "2147483501" sort as 2, 10, 2147483501, then ""; a zwpad-prefixed title is stripped; IDX survives a QSettings round-trip; an app list that differs only in uuid or artVersion makes `updateAppList()` return true; notice app 114514 (empty UUID, IDX 0), returned only when the client has none of list, view or launch; a client with view\|launch and no list still gets the full list |
| `tst_launchurl` | `startApp` query string contains `appuuid`, `virtualDisplay`, `scaleFactor` and `clientName` when `isApollo()`; with the display preference at -1 it has no `virtualDisplay`. Stock and GFE hosts get none of these, and their `mode` is byte-identical to the base (integer Hz, 0 when fps>60 on GFE). The pure function `formatApolloRefresh(uint32 mHz)` returns Hz when `mHz % 1000 == 0`, otherwise mHz: 60000 -> `60`, 59940 -> `59940`, 119880 -> `119880`. It is used only when `isApollo()`. This matches Artemis Android `NvHTTP.java:854-861` and Vibepollo `nvhttp.cpp:3188-3191`. M1 always passes integer Hz times 1000; `STREAM_CONFIGURATION.fps` stays integer Hz (section 11) and is not changed by this task. Launch status handling (task 5): 410 maps to the informational outcome; 403 and 503 map to an error carrying the host's message |
| `tst_otp` | The getservercert request goes over plain HTTP (`m_BaseUrlHttp`), so `tlsfixture.h` cannot capture it. Add `tests/apollo/httpfixture.h`, a loopback `QTcpServer` that records the request line, or test a pure query-builder function. Asserts: `otpauth` equals the uppercase hex SHA-256 of pin + saltHex + passphrase, where saltHex is the exact lowercase `salt=` string sent. Vector: pin `1234`, salt `00112233445566778899aabbccddeeff`, passphrase `test` gives `CBF763E747142C2787CC74B38642B26C055C73C497DEAA0EF063030FE26F4542`. `devicename` equals the configured client name, not the base's `roth`. No passphrase means no `otpauth`, and the request is otherwise identical to the base. If the early check in 4.7 is implemented: a getservercert reply with status_code 200, paired=1 and status_message "OTP auth not available." gives the OTP-expired error |
| `tst_clipboard` | loopback TLS server (reuse `tlsfixture.h`): GET returns the plain-text body; POST sends the body with `Content-Type: text/plain` and `uniqueid`/`uuid` present; 401 maps to a permission error ("Clipboard permission denied by host"); 403 maps to "No active stream" (Smart sync ignores it silently); 400 maps to unsupported type; 500 surfaces as an error |
| `tst_servercmd` (C, common-c fork) | `tests/test_exec_server_cmd.c` in the fork's `tests/` (not `tests/apollo`) includes `../src/ControlStream.c`, like `tests/test_control_truncation.c` and `test_steam_haptic.c`, and captures the outgoing packet through a hook. It checks that the `IDX_EXEC_SERVER_CMD` row exists in all five tables (0x3000 in Gen7Enc, -1 in Gen3/4/5/7); that `LiSendExecServerCmd` returns failure without sending when there is no control stream, while stopping, and when the active table has no entry; and that it sends payload `{idx,0,0,0}` with type 0x3000 on `CTRL_CHANNEL_SERVERCTL` (8), reliable. It is registered in `tests/run-regressions.sh` (compile loop and run list; the list is hardcoded), so the fork's existing `ci.yml` `steam-regressions` job runs it |
| `tst_clipboardsync` | push on connect and focus gain, pull on focus loss, loop guard, Off/Manual/Smart |

Integration (manual, against the owner's Vibepollo host): OTP pair, then grant the new
DeckVoid device Launch, Clipboard and Server commands in the web UI (it starts with View and
List if another device is already paired); app order; launch on virtual and physical
display with scale 150 %; server command visible and executed; clipboard both ways;
revoking Launch in the web UI gives the launch 403 permission message; revoking clipboard
read/set (or both View and Launch) gives the clipboard 401 permission message. Then on the
Deck in Gaming Mode: quick menu renders and is navigable, no new windows.

## 10. Implementation plan (ordered; each task ends with passing tests and a checkpoint with the owner)

**Progress (2026-11-04).** Tasks 1-3 are done.
- The repository is at `/Users/omar/omar_apollo/deckvoid`, pushed to
  `github.com/oaa20203-source/deckvoid`, on base master `76ee5025`.
- CI was trimmed to `build.yml` (tests + Flatpak) and `build-flatpak.yml`. The Windows/macOS,
  AppImage, Steam Link, release and daily-prerelease workflows were deleted, and
  `.github/dependabot.yml` was removed. Still open from section 8:
  `scripts/verify-linux-features.py:13` still looks for `bin/moonlight`, and no CI job runs
  the Qt tests in `tests/tests.pro`.
- The library fork is `oaa20203-source/moonlight-common-c`, branch `deckvoid`, with
  `LiSendExecServerCmd` and `tests/test_exec_server_cmd.c`; the app's submodule points at it.
- Task 3 added `app/backend/apollo/apollohostinfo.h`, `apollopermissions.h` and `tests/apollo`.

1. **Repository setup. (Done.)** Fork Nonary/moonlight-qt at master commit `76ee5025` (the
   base chosen in section 0; Nonary tag `v6.2.0-daily.196` points at the same commit; not
   tag `v6.1.0-vrr18`, which lacks `launchwarning.h`, `poweractions.h` and
   `tests/power/tlsfixture.h`) into `oaa20203-source/deckvoid` with `upstream` remote; fork
   the common-c submodule; apply section 8; build on macOS; screenshot the unchanged UI with
   the new title. Checkpoint: owner sees "DeckVoid".
2. **Library packet. (Done.)** In the common-c fork: `#define CTRL_CHANNEL_SERVERCTL 0x08`
   (`Limelight-internal.h`), `IDX_EXEC_SERVER_CMD` appended to the IDX list, `0x3000` only
   in `packetTypesGen7Enc` and `-1` in Gen3/4/5/7 (same as Apollo c999436 and Nonary's
   0x55xx extensions). `int LiSendExecServerCmd(uint8_t cmdId)` sends `{cmdId,0,0,0}` with
   `sendMessageAndForget` on `CTRL_CHANNEL_SERVERCTL`, `ENET_PACKET_FLAG_RELIABLE`. It
   returns -1 without sending when the control stream is not up or the protocol has no
   entry (`peer == NULL || stopping || packetTypes == NULL ||
   packetTypes[IDX_EXEC_SERVER_CMD] == -1`), -2 when the send fails, and 0 on success
   (Li* convention; Apollo returns the bool, which is 1 on success). Prototype and return
   values are documented in `Limelight.h`. The guard does not take `enetMutex` or check
   `peer->state == ENET_PEER_STATE_CONNECTED` the way `isControlDataInTransit` does; if
   that stricter check is added, release the lock before calling `sendMessageAndForget`,
   because `sendMessageEnet` takes `enetMutex` itself. Test `tst_servercmd`
   (`tests/test_exec_server_cmd.c` via `tests/run-regressions.sh`). Bump the submodule in
   the app repo.
3. **Host info and permissions. (Done.)** `apollohostinfo.h`, `apollopermissions.h`;
   `NvComputer` field + `isApollo()` + `update()` + details text. `update()` uses
   `ASSIGN_IF_CHANGED`, which needs `!=`, and the app builds as C++17 (`app.pro:2`), so
   defaulted comparisons are not available. Either give `ApolloHostInfo` hand-written
   `operator==` and `operator!=` (what the implementation does), or copy its fields into
   `NvComputer` as scalar fields and assign each one in `update()`, the way the
   frame-limiter fields are handled (`nvcomputer.cpp:178-181`, `:580-586`). Tests
   `tst_apollohostinfo`, `tst_apollopermissions`. Checkpoint: screenshot of View Details on
   a mock host.
4. **App identity and order.** `NvApp` fields, `getAppList` parsing, `sortAppList`, notice
   tile, verb choice in `Session::startConnectionAsync` and AppView
   `launchOrResumeSelectedApp`. For Apollo hosts: if `currentgameuuid` is non-empty, send
   `resume` if it equals `app.uuid` (case-insensitive) and `launch` otherwise. If it is
   empty, use the stock check (`resume` iff currentGameId == app.id). Exception: if the
   running app is Remote Input (UUID `8CB5C136-DA67-4F99-B4A1-F9CD35005CF4`) and the user
   picks a different app, show no quit dialog and send `launch` for the new app; the host
   replaces the input-only session itself (`src/nvhttp.cpp:5383`). Never send `resume` in
   that case, because `/resume` takes no app identity and would reattach to Remote Input.
   Relax the `Q_ASSERT` at `session.cpp:1817` to allow it. Choosing the verb needs no
   `startApp` signature change. The `appuuid` parameter stays in task 5. Add `uuid`,
   `index` and `artVersion` to the `NvApp` SER keys, the `NvApp(QSettings&)` constructor,
   `NvApp::serialize()` **and `NvApp::operator==`**. `updateAppList()` and
   `isEqualSerialized()` both rely on that operator, so any field left out of it is never
   refreshed from the host or re-saved (for example, a cached app keeps an empty uuid and
   resume-by-UUID fails). `sortAppList()` decides from the persisted index, not from
   `isApollo()` (6.2), because the QSettings constructor sorts before any host info exists.
   Test `tst_nvapp_apollo`, including a case where an app list that differs only in uuid or
   artVersion makes `updateAppList()` return true.
5. **Launch options.** `apollolaunchoptions.h`, preferences (6.4) and SettingsView group,
   `startApp` changes, plumbing for the per-launch override: `Session` gains an optional
   `ApolloLaunchOptions` (or `int virtualDisplayOverride = -1`, where -1 means use the
   preference) constructor parameter that `startConnectionAsync` passes to `startApp`. Add
   `AppModel::createSessionForApp(int appIndex, int virtualDisplayOverride = -1)` as
   `Q_INVOKABLE`. AppView's new context-menu items call it with 0 or 1, and
   `launchOrResumeSelectedApp` takes and forwards the override. Store it on
   `quitAppDialog` too (a `nextVirtualDisplayOverride` property next to `nextAppIndex`,
   `AppView.qml:229-231` and `:388`) so a launch that first quits the running app keeps it.
   `computermodel.cpp:144` and `cli/startstream.cpp:105` keep the preference default.
   Millihertz `mode`, `clientName`. Status handling in the `startApp`/resume callers (catch
   `GfeHttpResponseException`, leave `verifyResponseStatus` unchanged): 410 is not an
   error, and this applies in M1 too: show `status_message` in an informational dialog, do
   not start the stream, then refresh serverinfo and the app list. 403: show
   `status_message` verbatim. 503 on resume: refresh serverinfo; if no app is running,
   retry once as `launch`, otherwise show `status_message`. Any other 503: show
   `status_message`, with no automatic retry. Add `TERMINATE_APP_UUID`
   (`"E16CBE1B-295D-4632-9A76-EC4180C857D3"`) to `apolloconstants.h`. AppView context-menu
   items and driver-not-ready confirm. Test `tst_launchurl` (including the 410/403/503
   mapping). Checkpoint: screenshots of the settings group and the context menu.
6. **OTP pairing.** `NvPairingManager::pair` optional passphrase and `devicename`,
   `pairHostWithOtp`, PcView menu item and dialog. Test `tst_otp`. Checkpoint: dialog
   screenshot, then a live pairing against the owner's host, and confirm the new device's
   permissions in the web UI before tasks 5 and 7 are tested live.
7. **Clipboard.** First extend the private `NvHTTP::openConnection` with optional trailing
   parameters `const QByteArray& body = {}` and `const QString& contentType = {}`. For
   `PostOperation`, set `ContentTypeHeader` when `contentType` is non-empty (do not limit
   this to `powerAction`) and call `network->post(request, body)`. In the error branch, for
   `command == "actions/clipboard"` read `HttpStatusCodeAttribute`; if it is >= 400, throw
   `GfeHttpResponseException(status, <message>)` with the status as received, the way the
   `pyrowave-udp-probe` branch does (`:812-823`), so callers can tell 401 (permission) from
   403 (no active stream); see 4.9 for every code. The host clipboard handlers return bare
   status codes with no XML `status_code`, so `verifyResponseStatus` cannot map them. Leave
   the existing power and pyrowave behavior unchanged. Then add public
   `QString NvHTTP::getClipboard()` (HTTPS GET `actions/clipboard`, argument `type=text`,
   returns the body as UTF-8) and `void NvHTTP::setClipboard(const QString&)` (HTTPS POST,
   same argument, UTF-8 body, `text/plain`). Then `ClipboardSync`, preference, Session
   triggers: push on connect and focus gain, pull on focus loss and on disconnect
   **before** `LiStopConnection` (the host answers 403 once the stream has ended); loop
   guard. Threading: while streaming, `Session::exec` runs the SDL event loop on the Qt
   main thread and Qt events are not processed (`session.cpp:2291-2292`). Queued Qt signals
   to Session are not delivered then, and `QClipboard` must not be used. `NvHTTP` blocks in
   a local `QEventLoop` (`openConnection`), so never call it from the SDL loop. During the
   stream, read and write the local clipboard only on the SDL main thread with
   `SDL_GetClipboardText` / `SDL_SetClipboardText`. Read the text there before handing it
   off. Run each `NvHTTP` clipboard call as a `QThreadPool` task (pattern:
   `PendingSleepTask`, `computermanager.cpp:702-725`). Return the result to the loop with
   `SDL_PushEvent(SDL_USEREVENT)` using a new `SDL_CODE_APOLLO_CLIPBOARD` (107 or higher;
   100-105 are in `session.cpp:37-42` and 106 is `SDL_CODE_STEAM_CONTROLLER_LINK` in
   `input/steamcontroller/steamcontrollerhost.h`). Handle that code in the `SDL_USEREVENT`
   switch in `Session::exec`. Trigger push and pull from `SDL_WINDOWEVENT_FOCUS_GAINED` /
   `FOCUS_LOST` (`session.cpp:2430-2441`). Do the disconnect pull synchronously inside
   `DeferredSessionCleanupTask::run()` (a pool thread) before `LiStopConnection()`
   (`session.cpp:1519`). SDL video is already shut down at that point
   (`SDL_QuitSubSystem(SDL_INIT_VIDEO)` runs at the end of `exec`) and the Qt event loop has
   resumed, so deliver the pulled text to the Qt GUI thread (`QMetaObject::invokeMethod`
   with `Qt::QueuedConnection` on a main-thread object) and set it with
   `QGuiApplication::clipboard()`, not SDL. Tests `tst_clipboard`, `tst_clipboardsync`.
8. **Quick menu v0.** Overlay list (new `OverlayQuickMenu` type positioned in each
   renderer, 6.3), chord and key combo, input capture while open, items wired to
   `Session::execServerCommand`, clipboard, stats, disconnect, quit. Checkpoint: screenshot
   on macOS, then on the Deck.
9. **CI and Flatpak.** Workflows were trimmed and renamed in task 1; finish the open
   section 8 CI items (Qt test job, `verify-linux-features.py`). First Flatpak artifact
   installed on the Deck; Gaming Mode check of 6.3. Checkpoint: owner tests on the Deck.
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
- Artemis Qt's clipboard POST omitted `uniqueid`/`uuid`. Route clipboard calls through
  `openConnection` so they keep them, after extending it with a body and Content-Type as
  described in task 7.
- Control packet 0x3001 looks like clipboard but Vibepollo discards it.
- Do not report the Deck's built-in controller with the Steam Controller 2026 capability
  bits (grip, haptic, click); Vibepollo treats it as a plain pad (`src/platform/windows/vhf_gamepad_policy.h:107`).
  The base's `SDL_CONTROLLER_TYPE_STEAMDECK` case (`app/streaming/input/gamepad.cpp:511-514`)
  is dead code. Its `#ifdef` tests an enum name, not a macro, and the SDL2 2.32 headers in
  `deckvoid/libs` do not define that enumerator at all. The Deck's built-in controls
  therefore never get `LI_CTYPE_STEAM`. In Gaming Mode they reach SDL as Steam's virtual pad
  (28de:11ff) and are reported as `LI_CTYPE_XBOX` (or `LI_CTYPE_UNKNOWN`), with no Steam
  capability bits. That is the plain-pad behaviour Vibepollo expects. Do not change this in
  M1. The base's separate Steam Controller (2026) path (`app/streaming/input/steamcontroller/`)
  sends `LI_CTYPE_STEAM` with grip/haptic/click bits and is for that controller only. If a
  Deck-specific type is ever needed, detect VID 28de PID 1205 explicitly and never add
  `LI_CCAP_GRIP_SENSE`, `LI_CCAP_STEAM_HAPTIC` or `LI_CCAP_SC26_BUTTONS`.
- VoidLink's library IDs 0x5504/0x5505, input magic 0x55000008 and capability 0x200 collide
  with Vibepollo's Steam Controller extensions. Never merge `voidlink-c`.

## 12. Later milestones (facts gathered; specs to be written when M1 ships)

**M2, Deck OLED performance and haptics (owner's top priority).**
- Panel: 1280x800, 90 Hz, no VRR on the internal display. Target 90 fps with the panel at
  90 Hz, fixed pacing (the base's VRR path is for external VRR displays). The base contains
  a GamescopeComposition helper (`app/streaming/gamescopecomposition.cpp`), but nothing in
  `app/` calls it. Only `tests/vrr/tst_gamescopecomposition.cpp` uses it, and its setting
  was retired (`streamingpreferences.cpp:453` removes `gamescopeforcecomposition`). It only
  reads and sets `composite_force`; it has no refresh control. Re-check this at the pinned
  base commit. Setting the panel refresh from the client is unverified. First check on
  device whether the installed `gamescopectl` exposes any refresh control. If it does not,
  rely on Steam's per-game Refresh Rate for the DeckVoid shortcut (90 Hz) and document that
  step. Any session-wide `gamescopectl` change (such as `composite_force`) must be asked for
  first and restored on exit.
- Codec: the Deck APU (Van Gogh, VCN 3.x) can hardware-decode HEVC Main10 and AV1 Main
  (8/10-bit). AV1 support is shown by the base's RADV Vulkan probe
  (`docs/vrr-render-handoff-study-20260910.md`, "Native Vulkan decoding"), which exposed AV1
  decode extensions, and by Mesa VA-API (general knowledge). Confirm `VAProfileAV1Profile0`
  with `vainfo` on the owner's Deck. Pick HEVC Main10 or AV1 by measuring decode time and
  quality per Mbps on the device through the base's VAAPI path. AV1 also needs an
  AV1-capable encoder on the host GPU. Use Vibepollo's per-client "prefer 10-bit SDR". HDR
  goes through the base's HDR10 Vulkan swapchain under Gamescope.
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
- Whether `gamescopectl` can run from inside the Flatpak. The base's fallback
  (`distrobox-host-exec` + `host-spawn`, `gamescopecomposition.cpp:24-34`) is for the
  Distrobox dev setup only and cannot work in the Flatpak. The manifest grants
  `--filesystem=xdg-run/gamescope-0` but not `--talk-name=org.freedesktop.Flatpak`, so
  `flatpak-spawn --host` is unavailable. If a gamescopectl call is needed, bundle
  gamescopectl in the Flatpak manifest (it can reach the exposed socket). Do not add
  `org.freedesktop.Flatpak` host-spawn access without the owner's approval.
- Base is settled: master `76ee5025` / `v6.2.0-daily.196` (section 0; master reports
  6.2.0). When Nonary cuts a release tag that contains `76ee5025`, decide with the owner
  whether to rebase onto it, and re-check the section 5 line numbers if so; until then stay
  on `76ee5025`. Do not move back to `v6.1.0-vrr18`, which lacks `launchwarning.h`,
  `poweractions.h` and `tests/power/tlsfixture.h`.

## 14. Definition of done for milestone 1

All tests in section 9 pass in CI. Against the owner's Vibepollo host: OTP pairing works
from the Deck; apps appear in host order; an app launches on the virtual display at
150 % scale and on the physical display with the warning shown; a server command runs;
clipboard syncs both ways; revoking "Launch" in the web UI produces the permission
message. Sunshine hosts behave exactly as before. The owner has seen and approved
screenshots of every screen in section 6 on macOS and on the Deck.
