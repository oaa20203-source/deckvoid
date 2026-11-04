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

Flatpak bundles are built by GitHub Actions for every commit to `main`
(Actions tab, artifact `DeckVoid-Flatpak-*`). In Desktop Mode:

```bash
flatpak install --user ./DeckVoid-*-x86_64.flatpak
```

Then add DeckVoid as a non-Steam game and launch it from Gaming Mode.

DeckVoid uses its own app ID (`io.github.oaa20203_source.deckvoid`) and settings, so it
installs next to stock Moonlight. Hosts paired in Moonlight are **not** carried over;
pair again in DeckVoid.

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
