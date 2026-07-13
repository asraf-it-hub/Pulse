import 'package:flutter/material.dart';

import '../../../services/player_engine/player_engine.dart';
import '../application/player_controller.dart';

class PulseMiniPlayer extends StatelessWidget {
  const PulseMiniPlayer({
    required this.playerController,
    required this.onOpenPlayer,
    super.key,
  });

  final PlayerController playerController;
  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playerController,
      builder: (context, _) {
        final current = playerController.current;
        if (current == null) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<PlaybackSnapshot>(
          valueListenable: playerController.snapshot,
          builder: (context, snapshot, _) {
            final theme = Theme.of(context);
            return Material(
              color: theme.colorScheme.surfaceContainer,
              child: InkWell(
                onTap: onOpenPlayer,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Icon(current.isVideo ? Icons.movie_rounded : Icons.music_note_rounded),
                        const SizedBox(width: 12),
                        Expanded(child: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        IconButton(
                          tooltip: snapshot.playing ? 'Pause' : 'Play',
                          onPressed: playerController.togglePlay,
                          icon: Icon(snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                        IconButton(
                          tooltip: 'Next',
                          onPressed: playerController.next,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
