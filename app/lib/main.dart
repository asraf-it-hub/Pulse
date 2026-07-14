import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'pulse_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  runApp(const PulseApp());
}
