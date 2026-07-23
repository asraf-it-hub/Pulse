import 'package:flutter/material.dart';

import '../../../core/theme/pulse_theme.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.settingsController, super.key});

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final settings = settingsController.settings;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme preset', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final preset in PulseThemePreset.values)
                          ChoiceChip(
                            selected: settings.preset == preset,
                            label: Text(_label(preset)),
                            onSelected: (_) => settingsController.update(settings.copyWith(preset: preset)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personalization', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _SliderSetting(
                      label: 'Corner radius',
                      value: settings.cornerRadius,
                      min: 8,
                      max: 36,
                      onChanged: (value) => settingsController.update(settings.copyWith(cornerRadius: value)),
                    ),
                    _SliderSetting(
                      label: 'Blur intensity',
                      value: settings.blurIntensity,
                      min: 0,
                      max: 32,
                      onChanged: (value) => settingsController.update(settings.copyWith(blurIntensity: value)),
                    ),
                    _SliderSetting(
                      label: 'Animation speed',
                      value: settings.animationSpeed,
                      min: 0.5,
                      max: 1.5,
                      onChanged: (value) => settingsController.update(settings.copyWith(animationSpeed: value)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final color in const [Color(0xffff6b3d), Color(0xff55d6be), Color(0xff7c5cff), Color(0xff2f8f5b), Color(0xffffb84d)])
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => settingsController.update(settings.copyWith(accentColor: color)),
                            child: CircleAvatar(
                              backgroundColor: color,
                              child: settings.accentColor.toARGB32() == color.toARGB32() ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Playback & Controls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _SliderSetting(
                      label: 'Skip interval (seconds)',
                      value: settings.skipDuration,
                      min: 5,
                      max: 60,
                      onChanged: (value) => settingsController.update(settings.copyWith(skipDuration: value.roundToDouble())),
                    ),
                    _SliderSetting(
                      label: 'Volume step size (%)',
                      value: settings.volumeStep * 100.0,
                      min: 1,
                      max: 20,
                      onChanged: (value) => settingsController.update(settings.copyWith(volumeStep: value.roundToDouble() / 100.0)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _label(PulseThemePreset preset) {
    return switch (preset) {
      PulseThemePreset.system => 'System',
      PulseThemePreset.light => 'Light',
      PulseThemePreset.dark => 'Dark',
      PulseThemePreset.amoled => 'AMOLED',
      PulseThemePreset.glass => 'Glass',
      PulseThemePreset.minimal => 'Minimal',
      PulseThemePreset.midnightBlue => 'Midnight',
      PulseThemePreset.forest => 'Forest',
      PulseThemePreset.purple => 'Purple',
      PulseThemePreset.sunset => 'Sunset',
    };
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.toStringAsFixed(1)),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

