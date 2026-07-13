import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/models/media_item.dart';
import 'package:pulse/core/theme/pulse_theme.dart';

void main() {
  test('MediaItem round-trips through JSON', () {
    final item = MediaItem(
      id: 'sample',
      title: 'Midnight Signal',
      uri: 'C:/Media/midnight.mp4',
      kind: MediaKind.video,
      artist: 'Pulse',
      album: 'Phase 2',
      genre: 'Demo',
      duration: const Duration(minutes: 4, seconds: 12),
      addedAt: DateTime.utc(2026, 7, 13),
      lastPlayedAt: DateTime.utc(2026, 7, 13, 10),
      isFavorite: true,
      resumePosition: const Duration(seconds: 42),
    );

    final restored = MediaItem.fromJson(item.toJson());

    expect(restored.id, item.id);
    expect(restored.title, item.title);
    expect(restored.kind, MediaKind.video);
    expect(restored.isFavorite, isTrue);
    expect(restored.resumePosition, const Duration(seconds: 42));
  });

  test('Pulse theme presets map to expected theme modes', () {
    expect(PulseThemeFactory.modeFor(PulseThemePreset.system), ThemeMode.system);
    expect(PulseThemeFactory.modeFor(PulseThemePreset.light), ThemeMode.light);
    expect(PulseThemeFactory.modeFor(PulseThemePreset.minimal), ThemeMode.light);
    expect(PulseThemeFactory.modeFor(PulseThemePreset.dark), ThemeMode.dark);
  });
}
