# Notchly

Notchly is a native macOS menu bar app that brings a compact Dynamic Island-style overlay to the notch area. It shows battery state, Now Playing controls, artwork-aware waveform color, and a small lock-screen transition without taking over the desktop.

## Highlights

- Dynamic Island-style overlay positioned around the macOS notch/safe area
- Compact and expanded battery states with charging and low-battery feedback
- Now Playing controls with play/pause, previous/next, seeking, artwork, source app opening, and animated waveform
- Track preview state when music starts, changes, or is skipped
- Lock-screen overlay with optional unlock sound
- Menu bar controls for settings, update checks, and quit
- Settings window for general behavior, battery, music, and about information
- Sparkle update configuration kept in `Config/Info.plist`

## Requirements

- macOS 15.6 or newer
- Xcode 26 or newer
- A Mac display setup where notch/safe-area behavior is available

## Dependencies

Notchly uses Swift Package Manager through the Xcode project:

- [Sparkle](https://sparkle-project.org/) for app update checks
- [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow) for the overlay window integration
- [mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter) for Now Playing / MediaRemote access

The app also links against Apple's private `MediaRemote` framework. That makes the music experience possible, but it has distribution implications: private APIs can affect App Store eligibility, notarization expectations, and long-term compatibility.

## Build

1. Open `Notchly.xcodeproj` in Xcode.
2. Let Xcode resolve Swift Package Manager dependencies.
3. Select the `Notchly` scheme.
4. Build and run.

Command-line build:

```sh
xcodebuild -project Notchly.xcodeproj -scheme Notchly -configuration Debug build
```

For a sandbox-friendly local build with a custom derived data folder:

```sh
xcodebuild \
  -project Notchly.xcodeproj \
  -scheme Notchly \
  -configuration Debug \
  -derivedDataPath /tmp/notchly-derived \
  build
```

## Update Configuration

Sparkle reads its appcast and signing configuration from `Config/Info.plist`.

Important keys:

- `SUFeedURL`: appcast URL
- `SUPublicEDKey`: Sparkle EdDSA public key
- `SUEnableAutomaticChecks`: automatic update checks
- `SUAutomaticallyUpdate`: automatic update installation behavior
- `SUScheduledCheckInterval`: update check interval

The Xcode target points at this file with:

```text
INFOPLIST_FILE = Config/Info.plist
```

So `Notchly/Info.plist` is intentionally not used anymore.

## Project Structure

- `Config`: app configuration files, including the Sparkle-backed `Info.plist`
- `Notchly/App`: app lifecycle, dependency container, menu bar, overlay, Sparkle, and lock-screen coordinators
- `Notchly/Managers`: observable runtime state for settings, music, battery, and island module selection
- `Notchly/Models`: small domain models shared across managers and views
- `Notchly/Views`: SwiftUI views grouped by island, settings, and shared UI
- `Notchly/Windows`: AppKit wrappers for standalone app windows
- `Notchly/Helpers`: platform helpers and SwiftUI/AppKit bridges
- `Notchly/Resources`: assets, sounds, and bundled adapter framework resources
- `docs`: architecture notes and project documentation

See `docs/ARCHITECTURE.md` for the runtime flow and ownership map.

## Development Notes

- Keep app lifecycle and platform coordination in `Notchly/App`.
- Keep system API state behind managers in `Notchly/Managers`.
- Keep feature views presentational where possible.
- Keep `Package.resolved` tracked so builds use the same dependency revisions.
- Avoid committing local signing changes, DerivedData, archives, or Xcode user state.

## License

Notchly is released under the MIT License. See `LICENSE` for details.
