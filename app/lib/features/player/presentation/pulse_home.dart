import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/application/library_controller.dart';
import '../../library/presentation/library_screen.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/player_controller.dart';
import 'now_playing_screen.dart';
import 'pulse_mini_player.dart';

class PulseHome extends StatefulWidget {
  const PulseHome({
    required this.settingsController,
    required this.libraryController,
    required this.playerController,
    super.key,
  });

  final SettingsController settingsController;
  final LibraryController libraryController;
  final PlayerController playerController;

  @override
  State<PulseHome> createState() => _PulseHomeState();
}

class _PulseHomeState extends State<PulseHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
      NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Now Playing'),
      NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
    ];
    final pages = [
      LibraryScreen(libraryController: widget.libraryController, playerController: widget.playerController),
      NowPlayingScreen(playerController: widget.playerController, libraryController: widget.libraryController),
      SettingsScreen(settingsController: widget.settingsController),
    ];

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyO, control: true): _ImportFilesIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, control: true, shift: true): _ScanFolderIntent(),
        SingleActivator(LogicalKeyboardKey.space): _TogglePlaybackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekBackIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SeekForwardIntent(),
      },
      child: Actions(
        actions: {
          _ImportFilesIntent: CallbackAction<_ImportFilesIntent>(onInvoke: (_) => widget.libraryController.importFiles()),
          _ScanFolderIntent: CallbackAction<_ScanFolderIntent>(onInvoke: (_) => widget.libraryController.importFolder()),
          _TogglePlaybackIntent: CallbackAction<_TogglePlaybackIntent>(onInvoke: (_) => widget.playerController.togglePlay()),
          _SeekBackIntent: CallbackAction<_SeekBackIntent>(onInvoke: (_) => widget.playerController.seekRelative(const Duration(seconds: -10))),
          _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(onInvoke: (_) => widget.playerController.seekRelative(const Duration(seconds: 10))),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final content = AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
              );
              if (wide) {
                return Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        extended: constraints.maxWidth >= 1180,
                        selectedIndex: _index,
                        onDestinationSelected: (value) => setState(() => _index = value),
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 18),
                          child: Image.asset('assets/brand/pulse-logo.png', width: 44, height: 44),
                        ),
                        destinations: const [
                          NavigationRailDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: Text('Library')),
                          NavigationRailDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: Text('Now Playing')),
                          NavigationRailDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: Text('Settings')),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  ),
                  bottomNavigationBar: PulseMiniPlayer(playerController: widget.playerController, onOpenPlayer: () => setState(() => _index = 1)),
                );
              }
              return Scaffold(
                body: content,
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseMiniPlayer(playerController: widget.playerController, onOpenPlayer: () => setState(() => _index = 1)),
                    NavigationBar(selectedIndex: _index, onDestinationSelected: (value) => setState(() => _index = value), destinations: destinations),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImportFilesIntent extends Intent {
  const _ImportFilesIntent();
}

class _ScanFolderIntent extends Intent {
  const _ScanFolderIntent();
}

class _TogglePlaybackIntent extends Intent {
  const _TogglePlaybackIntent();
}

class _SeekBackIntent extends Intent {
  const _SeekBackIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}
