# Contributing

Thanks for wanting to improve Notchly. The project is intentionally small, but it touches a few macOS-specific APIs, so clear boundaries help a lot.

## Local Setup

1. Open `Notchly.xcodeproj`.
2. Let Xcode resolve packages.
3. Build the `Notchly` scheme.
4. Run SwiftLint if you have it installed:

```sh
swiftlint
```

## Development Guidelines

- Keep app lifecycle logic inside `Notchly/App` coordinators.
- Keep observable runtime state inside `Notchly/Managers`.
- Keep reusable value types in `Notchly/Models`.
- Prefer small SwiftUI views grouped by feature folder.
- Avoid adding direct AppKit/window logic to leaf SwiftUI views unless the bridge is the point of the file.
- Keep private-framework behavior isolated behind managers or adapters.
- Do not commit local signing changes, user data, DerivedData, or generated archives.

## Pull Request Checklist

- The app builds locally.
- User-facing behavior is described in the PR.
- New settings have defaults and persistence behavior.
- New UI is checked in compact and expanded island states.
- Private API or entitlement changes are called out explicitly.

## License

By contributing, you agree that your changes will be licensed under the MIT License.
