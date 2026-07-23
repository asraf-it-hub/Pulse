import 'package:flutter/material.dart';
import '../../../core/models/media_item.dart';
import '../../../core/models/radio_station_model.dart';
import '../../player/application/player_controller.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({
    required this.playerController,
    super.key,
  });

  final PlayerController playerController;

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final List<RadioStation> _customStations = [];
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _playStation(RadioStation station) {
    final mediaItem = MediaItem(
      id: station.id,
      title: station.title,
      artist: station.genre,
      album: 'Live Radio Stream',
      uri: station.streamUrl,
      kind: MediaKind.audio,
    );
    widget.playerController.playItem(mediaItem, [mediaItem]);
  }

  void _addCustomStation() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Radio Stream'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  prefixIcon: Icon(Icons.radio_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Stream URL (m3u8, mp3, aac)',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = _nameController.text.trim();
                final url = _urlController.text.trim();
                if (name.isNotEmpty && url.isNotEmpty) {
                  setState(() {
                    _customStations.add(RadioStation(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: name,
                      streamUrl: url,
                      genre: 'Custom Stream',
                    ));
                  });
                  _nameController.clear();
                  _urlController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Station'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allStations = [...RadioStation.curatedStations, ..._customStations];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Internet Radio (📻)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link_rounded),
            tooltip: 'Add Custom Stream',
            onPressed: _addCustomStation,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: allStations.length,
        itemBuilder: (context, index) {
          final station = allStations[index];
          final current = widget.playerController.current;
          final isPlayingCurrent = current?.id == station.id;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  isPlayingCurrent ? Icons.volume_up_rounded : Icons.radio_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                station.title,
                style: TextStyle(
                  fontWeight: isPlayingCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isPlayingCurrent ? theme.colorScheme.primary : null,
                ),
              ),
              subtitle: Text(station.genre),
              trailing: IconButton(
                icon: Icon(
                  isPlayingCurrent ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: theme.colorScheme.primary,
                  size: 36,
                ),
                onPressed: () => _playStation(station),
              ),
              onTap: () => _playStation(station),
            ),
          );
        },
      ),
    );
  }
}
