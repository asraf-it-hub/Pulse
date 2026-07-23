import 'package:flutter/material.dart';

class ABLooperWidget extends StatefulWidget {
  const ABLooperWidget({
    required this.currentPosition,
    required this.duration,
    required this.onSeek,
    super.key,
  });

  final Duration currentPosition;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<ABLooperWidget> createState() => _ABLooperWidgetState();
}

class _ABLooperWidgetState extends State<ABLooperWidget> {
  Duration? _pointA;
  Duration? _pointB;
  bool _loopEnabled = false;

  @override
  void didUpdateWidget(ABLooperWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loopEnabled && _pointA != null && _pointB != null) {
      if (widget.currentPosition >= _pointB! || widget.currentPosition < _pointA!) {
        widget.onSeek(_pointA!);
      }
    }
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.repeat_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'A-B Segment Looper',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: _loopEnabled,
                onChanged: (_pointA != null && _pointB != null)
                    ? (val) => setState(() => _loopEnabled = val)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('Point A (Start)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _pointA != null ? _format(_pointA!) : 'Not Set',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _pointA = widget.currentPosition),
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Set A'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('Point B (End)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _pointB != null ? _format(_pointB!) : 'Not Set',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _pointB = widget.currentPosition),
                          icon: const Icon(Icons.flag_rounded, size: 16),
                          label: const Text('Set B'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pointA != null || _pointB != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _pointA = null;
                  _pointB = null;
                  _loopEnabled = false;
                });
              },
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Reset Points'),
            ),
        ],
      ),
    );
  }
}
