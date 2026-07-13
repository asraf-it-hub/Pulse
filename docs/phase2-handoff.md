# Phase 2 Handoff - Core Media Player MVP

## Current Status

Phase 2 has started and the Flutter app shell is implemented in `app/`.

Verified:

- `flutter doctor -v` reports no issues.
- `flutter analyze` passes with no issues.
- `flutter test` passes.
- `flutter build web` passes and outputs to `app/build/web`.
- Website checks still pass with `npm test` and `npm run build`.

Blocked or pending:

- `flutter build windows --debug` is blocked until Windows Developer Mode is enabled for plugin symlinks.
- `flutter build apk --debug` timed out after 5 minutes during the first Gradle build. No APK was produced during this session; retry locally with a longer timeout after Gradle finishes warming up.

## Implemented App Architecture

The app follows a feature-first Clean Architecture direction:

- `lib/core/models` - shared domain models.
- `lib/core/theme` - Pulse theme engine.
- `lib/core/widgets` - reusable UI states.
- `lib/features/library` - library state, persistence, import UI.
- `lib/features/player` - playback state, player UI, mini player.
- `lib/features/settings` - theme/customization state and settings UI.
- `lib/services/media_scanner` - file picking/scanning abstraction.
- `lib/services/player_engine` - playback engine abstraction and media_kit adapter.

## Implemented Features

### App Foundation

- Flutter project generated for Android, Windows, and Web only.
- No iOS target added.
- Material 3 enabled.
- Pulse logo added as Flutter asset.
- Responsive navigation with mobile bottom navigation and desktop navigation rail.
- Adaptive page transitions through Flutter theme configuration.

### Theme Engine

Implemented theme presets:

- System
- Light
- Dark
- AMOLED
- Glass
- Minimal
- Midnight Blue
- Forest
- Purple
- Sunset

Implemented customizable settings model:

- Accent color
- Primary color field in model
- Corner radius
- Blur intensity field in model
- Animation speed field in model
- Font family field in model

Settings persistence uses `shared_preferences`.

### Media Library

Implemented:

- File import using `file_picker`.
- Audio/video extension filtering.
- Local persistence using `shared_preferences`.
- Search across title, artist, album, and genre.
- Filters for all, videos, music, favorites, recent.
- Sort by recently added, recently played, and title.
- Favorites.
- Recently played metadata.
- Resume position metadata.
- Loading, empty, and error states.

### Player

Implemented:

- Playback engine interface.
- `media_kit` player adapter.
- Audio/video open and playback.
- Play/pause.
- Previous/next.
- Seek bar.
- Relative 10-second seek controls.
- Playback speed control.
- Shuffle state.
- Repeat off/all/one state.
- Sleep timer state.
- Video rendering with `media_kit_video`.
- Audio artwork panel using Pulse branding.
- Mini player.

### Tests

Implemented tests for:

- `MediaItem` JSON round-trip.
- Theme preset to `ThemeMode` mapping.

## Important Files

- `app/lib/main.dart`
- `app/lib/pulse_app.dart`
- `app/lib/core/models/media_item.dart`
- `app/lib/core/theme/pulse_theme.dart`
- `app/lib/features/library/application/library_controller.dart`
- `app/lib/features/library/presentation/library_screen.dart`
- `app/lib/features/player/application/player_controller.dart`
- `app/lib/features/player/presentation/now_playing_screen.dart`
- `app/lib/features/player/presentation/pulse_home.dart`
- `app/lib/features/player/presentation/pulse_mini_player.dart`
- `app/lib/features/settings/application/settings_controller.dart`
- `app/lib/features/settings/presentation/settings_screen.dart`
- `app/lib/services/media_scanner/file_picker_media_scanner.dart`
- `app/lib/services/player_engine/media_kit_player_engine.dart`

## Commands

From repo root:

```bash
npm test
npm run build
```

From `app/`:

```bash
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build web
flutter run -d chrome
flutter run -d windows
```

After enabling Windows Developer Mode:

```bash
flutter build windows --debug
flutter build windows --release
```

For Android:

```bash
flutter build apk --debug
flutter build apk --release
```

## Required Local Setup

Enable Windows Developer Mode for Flutter desktop/plugin symlinks:

```powershell
start ms-settings:developers
```

Then turn on Developer Mode in Windows Settings.

## Remaining Phase 2 Work

### High Priority

- Enable Windows Developer Mode and verify Windows run/build.
- Retry Android APK build with a longer first-run timeout.
- Test real playback on Windows, Android, and Web with local files.
- Add Android storage/media permissions and runtime permission flow.
- Add platform-specific file/folder scanning beyond manual file import.
- Add drag-and-drop support for Windows and Web.
- Add keyboard shortcuts for desktop/web.
- Improve persistence so playback updates are throttled instead of saving on every position event.

### Player MVP Completion

- Fullscreen video mode.
- Picture-in-picture where supported.
- Subtitle track support.
- Audio track selection.
- Aspect ratio controls.
- Brightness/volume gestures on Android.
- Double-tap seek gestures.
- Lock controls.
- Landscape/portrait behavior.
- Background audio playback and notifications on Android.

### Library MVP Completion

- Folder browsing.
- Real metadata extraction for albums, artists, genres, duration, artwork.
- Thumbnail generation.
- Recently added and recently played polish.
- History page or detail view.
- Playlists and queue management UI.

### UI Polish

- Skeleton loading states.
- Richer artwork/background animation.
- Better now-playing visual hierarchy on small phones.
- Dedicated artist/album/genre pages.
- Theme preview cards.
- Accessibility audit for labels and focus traversal.

## Notes For Next Agent

Do not regenerate the app from scratch. Continue from `app/lib` and the generated Flutter platform folders.

Avoid implementing native-heavy features before verifying the Windows Developer Mode symlink requirement is resolved.

Start with:

1. `cd app`
2. `flutter pub get`
3. `flutter analyze`
4. `flutter test`
5. Enable Developer Mode if Windows build still complains.
6. `flutter run -d windows` or `flutter run -d chrome`

The app currently has a functional source-level MVP shell, not a fully production media player yet.
