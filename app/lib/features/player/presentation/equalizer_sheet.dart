import 'package:flutter/material.dart';
import '../application/player_controller.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({this.playerController, super.key});

  final PlayerController? playerController;

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  bool _enabled = true;
  late String _selectedPreset;
  late double _preamp;
  late List<double> _gains;

  final List<String> _frequencies = ['60Hz', '170Hz', '310Hz', '600Hz', '1kHz', '3kHz', '6kHz', '12kHz', '14kHz', '16kHz'];

  final Map<String, List<double>> _presets = {
    'Flat': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
    'Treble Boost': [0, 0, 0, 0, 1, 3, 5, 6, 7, 7],
    'Vocal Enhancer': [-2, -1, 1, 4, 5, 4, 2, 0, -1, -2],
    'Rock': [5, 3, 2, 0, -1, 1, 3, 4, 5, 5],
    'Pop': [2, 4, 5, 3, 0, -1, 2, 3, 4, 3],
    'Jazz': [3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
    'Classical': [4, 3, 2, 2, -1, -1, 0, 2, 3, 4],
  };

  @override
  void initState() {
    super.initState();
    final pc = widget.playerController;
    if (pc != null) {
      _selectedPreset = pc.equalizerPreset;
      _preamp = pc.equalizerPreamp;
      _gains = List.from(pc.equalizerGains);
    } else {
      _selectedPreset = 'Flat';
      _preamp = 0.0;
      _gains = List.filled(10, 0.0);
    }
  }

  void _updateEngine() {
    widget.playerController?.setEqualizer(_selectedPreset, _gains, _preamp);
  }

  void _applyPreset(String preset) {
    if (_presets.containsKey(preset)) {
      setState(() {
        _selectedPreset = preset;
        final list = _presets[preset]!;
        for (int i = 0; i < 10; i++) {
          _gains[i] = list[i];
        }
      });
      _updateEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 520,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
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
                  Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    '10-Band Graphic Equalizer',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: _enabled,
                onChanged: (val) => setState(() => _enabled = val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presets.keys.map((preset) {
                final isSelected = _selectedPreset == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(preset),
                    onSelected: _enabled ? (_) => _applyPreset(preset) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.volume_up_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pre-Amp Booster: +${_preamp.round()}dB',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _preamp,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  onChanged: _enabled
                      ? (v) {
                          setState(() => _preamp = v);
                          _updateEngine();
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Opacity(
              opacity: _enabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !_enabled,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (index) {
                    return Column(
                      children: [
                        Text(
                          '${_gains[index] > 0 ? '+' : ''}${_gains[index].round()}dB',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: theme.colorScheme.primary,
                                inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: _gains[index],
                                min: -12.0,
                                max: 12.0,
                                onChanged: (val) {
                                  setState(() {
                                    _gains[index] = val;
                                    _selectedPreset = 'Custom';
                                  });
                                  _updateEngine();
                                },
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _frequencies[index],
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
