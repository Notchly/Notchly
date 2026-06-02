<p align="center">
  <img src="Notchly/Resources/Assets.xcassets/AppIcon.appiconset/logo_256x256.png" width="96" height="96" alt="Notchly app icon">
</p>

<h1 align="center">Notchly</h1>

<p align="center">
  Turn your MacBook notch into a useful, interactive space.
</p>

<p align="center">
  <a href="https://notchly.xyz"><strong>Website</strong></a>
  ·
  <a href="https://github.com/Notchly/Notchly/releases/latest"><strong>Download</strong></a>
  ·
  <a href="https://cdn.notchly.xyz/notchly-preview.mp4"><strong>Preview</strong></a>
  ·
  <a href="https://x.com/i/status/2061860955928100956"><strong>Codex Alerts</strong></a>
  ·
  <a href="docs/ARCHITECTURE.md"><strong>Architecture</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.6%2B-black?style=flat-square&logo=apple" alt="macOS 14.6+">
  <img src="https://img.shields.io/badge/SwiftUI-Native-orange?style=flat-square&logo=swift" alt="Native SwiftUI app">
  <img src="https://img.shields.io/badge/Privacy-Friendly-green?style=flat-square" alt="Privacy friendly">
  <a href="https://github.com/Notchly/Notchly/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/Notchly/Notchly?style=flat-square&label=release">
  </a>
  <a href="https://github.com/Notchly/Notchly/blob/main/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/Notchly/Notchly?style=flat-square">
  </a>
  <a href="https://github.com/Notchly/Notchly/stargazers">
    <img alt="GitHub stars" src="https://img.shields.io/github/stars/Notchly/Notchly?style=flat-square">
  </a>
  <a href="https://github.com/Notchly/Notchly/releases">
    <img alt="Downloads" src="https://img.shields.io/github/downloads/Notchly/Notchly/total?style=flat-square">
  </a>
</p>

<p align="center">
  If Notchly makes your Mac feel better, please
  <a href="https://github.com/Notchly/Notchly/stargazers"><strong>star the project</strong></a>.
</p>

---

## Notchly

**Notchly** is a lightweight native macOS app that turns the MacBook notch into a compact control surface.

It adds music controls, battery status, lock screen support, focus animations, gestures, smooth transitions, and Codex AI alerts around the notch.

## Preview

<p align="center">

<img width="1920" height="1080" alt="s-preview" src="https://github.com/user-attachments/assets/4a3fb21b-0261-441e-bdf0-afe69f9cb342" />

</p>

## Highlights

- Music controls for Spotify, Apple Music, and supported media sources.
- Battery and charging indicators.
- Lock screen music controls.
- Focus mode animations.
- Swipe gestures for quick interactions.
- Multi-display behavior for primary screen setups.
- Codex AI alerts for approval and task completion events.
- Local-first design with no personal data collection.

## Codex AI Alerts

Notchly can show alerts for Codex sessions.

Enable it in **Settings → Codex**:

1. Turn on **Codex Alerts**.
2. Enable **Need Approval Sound** if you want approval alerts.
3. Enable **Task Completed Sound** if you want completion alerts.
4. Restart Codex so the local Stop hook can send completion events to Notchly.

Preview: https://x.com/i/status/2061860955928100956

## Requirements

- macOS 14.6 or newer.

## Installation

1. Download the latest DMG from [Releases](https://github.com/Notchly/Notchly/releases/latest).
2. Open the DMG.
3. Move Notchly to Applications.
4. Launch Notchly.

macOS may ask for Automation permission when using Spotify or Apple Music controls.

## Settings

- General behavior, launch at login, lock sound, and focus animations.
- Battery visibility and low-battery threshold.
- Music preview timing and AppleScript controls.
- Primary-display behavior for multi-monitor setups.
- Codex alerts, approval sound, task completed sound, and alert duration.

## Build From Source

```sh
git clone git@github.com:Notchly/Notchly.git
cd Notchly
open Notchly.xcodeproj
```

Or build from the command line:

```sh
xcodebuild -project Notchly.xcodeproj -scheme Notchly -configuration Debug build
```

## Dependencies

- [Sparkle](https://sparkle-project.org/) for app updates.
- [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow) for overlay windows.
- [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter) for Now Playing / MediaRemote access.

## Contributing

Pull requests are welcome.

Please keep platform integrations isolated, avoid committing local signing changes, and make sure the app builds before opening a PR.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Notchly is released under the MIT License. See [LICENSE](LICENSE).
