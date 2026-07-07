# Release Strategy

## Versioning

Pulse uses semantic versioning:

- Major: breaking architectural or platform changes.
- Minor: new user-facing features.
- Patch: fixes, polish, and compatibility updates.

## Channels

- Website: primary public distribution.
- GitHub Releases: build archive, release notes, APK, Windows installer, and web artifact links.
- Web deployment: static hosting from `website/` now, Flutter web build later.

## Expected Build Artifacts

- Android: signed APK.
- Windows: installer executable.
- Web: deployable static bundle with PWA manifest.

## Release Quality Bar

Each release should include platform smoke tests, media playback verification, responsive layout checks, and clear release notes.
