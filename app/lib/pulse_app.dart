import 'package:flutter/material.dart';

import 'core/theme/pulse_theme.dart';
import 'features/library/application/library_controller.dart';
import 'features/player/application/player_controller.dart';
import 'features/player/presentation/pulse_home.dart';
import 'features/settings/application/settings_controller.dart';
import 'services/media_scanner/file_picker_media_scanner.dart';
import 'services/player_engine/media_kit_player_engine.dart';

class PulseApp extends StatefulWidget {
  const PulseApp({super.key});

  @override
  State<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends State<PulseApp> {
  late final SettingsController settingsController;
  late final LibraryController libraryController;
  late final PlayerController playerController;

  @override
  void initState() {
    super.initState();
    settingsController = SettingsController()..load();
    libraryController = LibraryController(scanner: const FilePickerMediaScanner())..load();
    playerController = PlayerController(engine: MediaKitPlayerEngine(), libraryController: libraryController);
  }

  @override
  void dispose() {
    settingsController.dispose();
    libraryController.dispose();
    playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final settings = settingsController.settings;
        return MaterialApp(
          title: 'Pulse',
          debugShowCheckedModeBanner: false,
          themeMode: PulseThemeFactory.modeFor(settings.preset),
          theme: PulseThemeFactory.light(settings),
          darkTheme: PulseThemeFactory.dark(settings),
          home: PulseHome(
            settingsController: settingsController,
            libraryController: libraryController,
            playerController: playerController,
          ),
        );
      },
    );
  }
}
