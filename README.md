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

Everything happens in Desktop Mode, in the terminal. The download link always
gives the newest build of `main`.

### 1. Switch to Desktop Mode

Press the **Steam** button, then **Power** → **Switch to Desktop**.

### 2. Open the terminal

Open the application launcher (bottom left), then **System** → **Konsole**.
Press **Steam + X** for the on-screen keyboard, or plug in a keyboard. Press
Enter after each command.

### 3. Make sure Flathub is available

DeckVoid's runtime libraries come from Flathub.

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### 4. Download DeckVoid

```sh
curl -L -o ~/Downloads/DeckVoid-x86_64.flatpak https://github.com/oaa20203-source/deckvoid/releases/latest/download/DeckVoid-x86_64.flatpak
```

Check the download:

```sh
ls -lh ~/Downloads/DeckVoid-x86_64.flatpak
```

It should be about 7 MB. If it is only a few bytes, a new build is still being
published; try again in a few minutes.

### 5. Install

```sh
flatpak install --user -y ~/Downloads/DeckVoid-x86_64.flatpak
```

The first install also downloads the KDE runtime (a few hundred MB).

### 6. Try it

```sh
flatpak run io.github.oaa20203_source.deckvoid
```

### 7. Add it to Steam

Open **Steam** on the desktop, choose **Games** → **Add a Non-Steam Game to My
Library**, tick **DeckVoid**, and press **Add Selected Programs**.

### 8. Back to Gaming Mode

Double-click **Return to Gaming Mode** on the desktop. DeckVoid is in your
**Library** under **Non-Steam**.

### 9. Pair with your PC

Start DeckVoid. Your PC appears on the PCs screen (or choose **Add a PC** and type
its IP address). Select it and DeckVoid shows a 4-digit PIN; on the PC, open
Vibepollo's web page (**https://localhost:47990**), go to **PIN**, and type it in.

DeckVoid has its own settings and app ID (`io.github.oaa20203_source.deckvoid`),
so it sits next to stock Moonlight. PCs paired in Moonlight aren't carried over.

### Updating

Repeat step 4, then:

```sh
flatpak install --user -y --reinstall ~/Downloads/DeckVoid-x86_64.flatpak
```

Your settings and paired PCs are kept.

### Uninstalling

```sh
flatpak uninstall --user io.github.oaa20203_source.deckvoid
```

## Design

The interface follows the design kit in [`docs/design/KIT.md`](docs/design/KIT.md):
paper surfaces, IBM Plex Sans and Mono, flat cards, one red accent, and a ruled
header with controller hints along the bottom.

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
