import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/pulse_theme.dart';

class SettingsController extends ChangeNotifier {
  PulseThemeSettings _settings = const PulseThemeSettings();

  PulseThemeSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = PulseThemeSettings(
      preset: PulseThemePreset.values.byName(prefs.getString('themePreset') ?? PulseThemePreset.system.name),
      accentColor: Color(prefs.getInt('accentColor') ?? const Color(0xffff6b3d).toARGB32()),
      primaryColor: Color(prefs.getInt('primaryColor') ?? const Color(0xff101114).toARGB32()),
      cornerRadius: prefs.getDouble('cornerRadius') ?? 24,
      blurIntensity: prefs.getDouble('blurIntensity') ?? 18,
      animationSpeed: prefs.getDouble('animationSpeed') ?? 1,
      fontFamily: prefs.getString('fontFamily'),
    );
    notifyListeners();
  }

  Future<void> update(PulseThemeSettings settings) async {
    _settings = settings;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themePreset', settings.preset.name);
    await prefs.setInt('accentColor', settings.accentColor.toARGB32());
    await prefs.setInt('primaryColor', settings.primaryColor.toARGB32());
    await prefs.setDouble('cornerRadius', settings.cornerRadius);
    await prefs.setDouble('blurIntensity', settings.blurIntensity);
    await prefs.setDouble('animationSpeed', settings.animationSpeed);
    if (settings.fontFamily == null) {
      await prefs.remove('fontFamily');
    } else {
      await prefs.setString('fontFamily', settings.fontFamily!);
    }
  }
}

