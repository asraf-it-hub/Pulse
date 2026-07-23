import 'dart:io' as io;
import 'package:flutter/foundation.dart';

class LyricLine {
  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  final Duration timestamp;
  final String text;
}

class LyricsController extends ChangeNotifier {
  final List<LyricLine> _lines = [];
  bool _loading = false;

  List<LyricLine> get lines => List.unmodifiable(_lines);
  bool get loading => _loading;
  bool get hasLyrics => _lines.isNotEmpty;

  void parseLrcText(String content) {
    _lines.clear();
    final RegExp regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    for (final line in content.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match != null) {
        final min = int.tryParse(match.group(1)!) ?? 0;
        final sec = int.tryParse(match.group(2)!) ?? 0;
        final msStr = match.group(3)!;
        final ms = int.tryParse(msStr.padRight(3, '0')) ?? 0;
        final text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          _lines.add(LyricLine(
            timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }
    _lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  Future<void> loadForMediaUri(String uri) async {
    _loading = true;
    notifyListeners();
    try {
      if (!kIsWeb) {
        final lrcPath = uri.replaceAll(RegExp(r'\.[^.]+$'), '.lrc');
        final file = io.File(lrcPath);
        if (file.existsSync()) {
          final content = await file.readAsString();
          parseLrcText(content);
          _loading = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    _lines.clear();
    _loading = false;
    notifyListeners();
  }

  int getActiveLineIndex(Duration position) {
    if (_lines.isEmpty) return -1;
    for (int i = _lines.length - 1; i >= 0; i--) {
      if (position >= _lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }
}
