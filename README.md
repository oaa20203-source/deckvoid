# DeckVoid

DeckVoid is a game streaming client for the **Steam Deck OLED**, built for
[Apollo](https://github.com/ClassicOldSong/Apollo) and
[Vibepollo](https://github.com/Nonary/Vibepollo) hosts. It also works with Sunshine.

It is based on [Moonlight](https://github.com/moonlight-stream/moonlight-qt) via
[Nonary's VRR fork](https://github.com/Nonary/moonlight-qt), which brings PyroWave,
VRR pacing, DualSense waveform haptics and Steam Controller support.

> Status: early development (milestone 1). Not ready for general use.

## Goals

1. **Apollo compatibility:** OTP pairing, virtual display and scale factor per launch,
   server commands, clipboard sync, per-client permissions, apps in the host's order.
2. **Steam Deck OLED first:** 1280x800 at 90 Hz, smooth pacing, responsive input and
   haptics, the best picture per megabit the Deck can decode.
3. **A handheld-friendly in-stream menu** inspired by VoidLink and Artemis.

The design and plan live in [`docs/superpowers/specs`](docs/superpowers/specs).

## Install on Steam Deck

You don't need a terminal or a GitHub account for this. Everything happens in the
Deck's Desktop Mode with the touchscreen or trackpads.

### What you need

- A Windows PC running [Vibepollo](https://github.com/Nonary/vibepollo) or Apollo, on
  the same network as the Deck.
- About 1 GB of free space on the Deck (the first install also downloads the KDE
  runtime DeckVoid uses).

### 1. Switch to Desktop Mode

Press the **Steam** button, choose **Power**, then **Switch to Desktop**.

To type in Desktop Mode, press **Steam + X** to bring up the on-screen keyboard.

### 2. Download DeckVoid

Open a web browser on the Deck. If there isn't one, open **Discover** (the shopping-bag
icon in the taskbar), search for **Firefox**, and press **Install**.

In the browser, go to this address. The download starts straight away:

**https://github.com/oaa20203-source/deckvoid/releases/latest/download/DeckVoid-x86_64.flatpak**

The file is saved to your **Downloads** folder.

### 3. Install it

1. Open **Dolphin**, the file manager (the folder icon in the taskbar).
2. Click **Downloads** on the left.
3. Double-click **DeckVoid-x86_64.flatpak**. **Discover** opens with DeckVoid's page.
4. Press **Install** and wait for it to finish. The first time can take a few minutes.

If double-clicking opens something other than Discover, right-click the file, choose
**Open With**, and pick **Discover**.

### 4. Add DeckVoid to Steam

1. Open **Steam** from the desktop.
2. Click **Games** in the top menu, then **Add a Non-Steam Game to My Library**.
3. Tick **DeckVoid** in the list and press **Add Selected Programs**.

### 5. Go back to Gaming Mode

Double-click **Return to Gaming Mode** on the desktop. DeckVoid is now in your
**Library**, under **Non-Steam**.

### 6. Pair with your PC

1. Start DeckVoid. Your PC should appear on the Hosts screen. If it doesn't, choose
   **Add PC** and type the PC's IP address.
2. Select the PC. DeckVoid shows a 4-digit PIN.
3. On the PC, open Vibepollo's web page (**https://localhost:47990**), go to the **PIN**
   page, and type the PIN in.

DeckVoid has its own settings and app ID (`io.github.oaa20203_source.deckvoid`), so it
sits next to stock Moonlight. PCs paired in Moonlight aren't carried over, so pair them
again in DeckVoid.

### Updating

Repeat steps 1 to 3. The download link always gives the newest build, and Discover
replaces the old version. Your settings and paired PCs are kept.

### Uninstalling

Open **Discover**, go to **Installed**, find **DeckVoid**, and press **Remove**.

### If Discover won't install the file

Open **Konsole** (search for it in the application menu), type this line and press
Enter:

```
flatpak install --user ~/Downloads/DeckVoid-x86_64.flatpak
```

Answer **y** to any questions. This works in Konsole's default shell; you don't
need to install anything else.

## Building

Same requirements as Moonlight-qt (Qt 6, FFmpeg, SDL2, OpenSSL, Opus). On macOS:

```bash
brew install qt
python3 setup-deps.py
qmake6 moonlight-qt.pro && make -j
```

The Linux Flatpak manifest is in `packaging/flatpak/`.

## Credits

- [Moonlight](https://github.com/moonlight-stream/moonlight-qt) by the Moonlight Game Streaming Project
- [Nonary's moonlight-qt fork](https://github.com/Nonary/moonlight-qt) and [Vibepollo](https://github.com/Nonary/Vibepollo)
- [Apollo](https://github.com/ClassicOldSong/Apollo) and [Artemis](https://github.com/ClassicOldSong/moonlight-android) by ClassicOldSong
- [VoidLink](https://github.com/The-Fried-Fish/VoidLink-previously-moonlight-zwm) by True砖家 and contributors, for in-stream UX ideas

Licensed under GPL-3.0, like Moonlight. The original Moonlight README is kept in
[`docs/upstream-moonlight-README.md`](docs/upstream-moonlight-README.md).
