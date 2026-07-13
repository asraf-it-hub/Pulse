import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulse/core/models/media_item.dart';
import 'package:pulse/features/library/application/library_controller.dart';
import 'package:pulse/services/media_scanner/media_scanner.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('importFiles adds picked media to the library', () async {
    final controller = LibraryController(
      scanner: _FakeScanner([
        MediaItem(
          id: 'C:/Media/song.mp3',
          title: 'song',
          uri: 'C:/Media/song.mp3',
          kind: MediaKind.audio,
          addedAt: DateTime.utc(2026, 7, 13),
        ),
      ]),
    );
    await controller.load();

    await controller.importFiles();

    expect(controller.error, isNull);
    expect(controller.items, hasLength(1));
    expect(controller.items.single.title, 'song');
  });

  test('importFiles treats an empty picker result as cancel', () async {
    final controller = LibraryController(scanner: const _FakeScanner([]));
    await controller.load();

    await controller.importFiles();

    expect(controller.error, isNull);
    expect(controller.items, isEmpty);
    expect(controller.loading, isFalse);
  });

  test('importFiles exposes scanner errors for debugging', () async {
    final controller = LibraryController(scanner: _ThrowingScanner());
    await controller.load();

    await controller.importFiles();

    expect(controller.error, contains('picker unavailable'));
    expect(controller.loading, isFalse);
  });
}

class _FakeScanner implements MediaScanner {
  const _FakeScanner(this.items);

  final List<MediaItem> items;

  @override
  Future<List<MediaItem>> pickFiles() async => items;
}

class _ThrowingScanner implements MediaScanner {
  @override
  Future<List<MediaItem>> pickFiles() async {
    throw StateError('picker unavailable');
  }
}

