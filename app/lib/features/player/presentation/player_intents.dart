import 'package:flutter/widgets.dart';

class ImportFilesIntent extends Intent {
  const ImportFilesIntent();
}

class ScanFolderIntent extends Intent {
  const ScanFolderIntent();
}

class TogglePlaybackIntent extends Intent {
  const TogglePlaybackIntent();
}

class SeekBackIntent extends Intent {
  const SeekBackIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

class ToggleMuteIntent extends Intent {
  const ToggleMuteIntent();
}

class ToggleFullscreenIntent extends Intent {
  const ToggleFullscreenIntent();
}

class CloseVideoIntent extends Intent {
  const CloseVideoIntent();
}
