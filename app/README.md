# Pulse Flutter App

Phase 2 starts here: a cross-platform Flutter media player for Android, Windows, and Web.

## Local setup

Install Flutter, then run:

```bash
cd app
flutter pub get
flutter create --platforms=android,windows,web .
flutter test
flutter run -d windows
```

The source already avoids iOS-specific assumptions. Platform folders are intentionally generated locally so Flutter can create the correct native files for the installed SDK version.
