class RadioStation {
  const RadioStation({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.genre,
    this.iconName = 'radio',
  });

  final String id;
  final String title;
  final String streamUrl;
  final String genre;
  final String iconName;

  static const List<RadioStation> curatedStations = [
    RadioStation(
      id: 'lofi-1',
      title: 'Lofi Girl - Chill Beats',
      streamUrl: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
      genre: 'Lo-Fi / Chill',
      iconName: 'headset',
    ),
    RadioStation(
      id: 'synthwave-1',
      title: 'Nightride FM - Synthwave & Cyberpunk',
      streamUrl: 'https://stream.nightride.fm/nightride.m4a',
      genre: 'Synthwave',
      iconName: 'electric_bolt',
    ),
    RadioStation(
      id: 'jazz-1',
      title: 'Smooth Jazz Global',
      streamUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
      genre: 'Jazz & Blues',
      iconName: 'music_note',
    ),
    RadioStation(
      id: 'rock-1',
      title: 'Classic Rock HD',
      streamUrl: 'https://stream.zeno.fm/7c2292f758quv',
      genre: 'Classic Rock',
      iconName: 'album',
    ),
    RadioStation(
      id: 'ambient-1',
      title: 'Deep Ambient Sleeping',
      streamUrl: 'https://stream.zeno.fm/8q2wbhpmdg8uv',
      genre: 'Ambient / Chillout',
      iconName: 'bedtime',
    ),
  ];
}
