import 'package:flutter/material.dart';

enum PulseThemePreset { system, light, dark, amoled, glass, minimal, midnightBlue, forest, purple, sunset }

class PulseThemeSettings {
  const PulseThemeSettings({
    this.preset = PulseThemePreset.system,
    this.accentColor = const Color(0xffff6b3d),
    this.primaryColor = const Color(0xff101114),
    this.cornerRadius = 24,
    this.blurIntensity = 18,
    this.animationSpeed = 1,
    this.fontFamily,
  });

  final PulseThemePreset preset;
  final Color accentColor;
  final Color primaryColor;
  final double cornerRadius;
  final double blurIntensity;
  final double animationSpeed;
  final String? fontFamily;

  PulseThemeSettings copyWith({
    PulseThemePreset? preset,
    Color? accentColor,
    Color? primaryColor,
    double? cornerRadius,
    double? blurIntensity,
    double? animationSpeed,
    String? fontFamily,
  }) {
    return PulseThemeSettings(
      preset: preset ?? this.preset,
      accentColor: accentColor ?? this.accentColor,
      primaryColor: primaryColor ?? this.primaryColor,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class PulseThemeFactory {
  const PulseThemeFactory._();

  static ThemeMode modeFor(PulseThemePreset preset) {
    return switch (preset) {
      PulseThemePreset.system => ThemeMode.system,
      PulseThemePreset.light || PulseThemePreset.minimal => ThemeMode.light,
      _ => ThemeMode.dark,
    };
  }

  static ThemeData light(PulseThemeSettings settings) {
    return _theme(
      brightness: Brightness.light,
      seed: settings.accentColor,
      surface: const Color(0xfff8f4ee),
      text: const Color(0xff181715),
      settings: settings,
    );
  }

  static ThemeData dark(PulseThemeSettings settings) {
    final surface = switch (settings.preset) {
      PulseThemePreset.amoled => Colors.black,
      PulseThemePreset.midnightBlue => const Color(0xff07111f),
      PulseThemePreset.forest => const Color(0xff07150f),
      PulseThemePreset.purple => const Color(0xff160d24),
      PulseThemePreset.sunset => const Color(0xff21100c),
      _ => const Color(0xff101114),
    };
    return _theme(
      brightness: Brightness.dark,
      seed: settings.accentColor,
      surface: surface,
      text: const Color(0xfff7f3eb),
      settings: settings,
    );
  }

  static ThemeData _theme({
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required Color text,
    required PulseThemeSettings settings,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness, surface: surface);
    final radius = BorderRadius.circular(settings.cornerRadius);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: settings.fontFamily,
      scaffoldBackgroundColor: surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: brightness == Brightness.dark ? 0.38 : 0.72),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
    );
  }
}

