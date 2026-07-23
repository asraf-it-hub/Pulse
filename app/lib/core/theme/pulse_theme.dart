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
    this.skipDuration = 10,
    this.volumeStep = 0.05,
  });

  final PulseThemePreset preset;
  final Color accentColor;
  final Color primaryColor;
  final double cornerRadius;
  final double blurIntensity;
  final double animationSpeed;
  final String? fontFamily;
  final double skipDuration;
  final double volumeStep;

  PulseThemeSettings copyWith({
    PulseThemePreset? preset,
    Color? accentColor,
    Color? primaryColor,
    double? cornerRadius,
    double? blurIntensity,
    double? animationSpeed,
    String? fontFamily,
    double? skipDuration,
    double? volumeStep,
  }) {
    return PulseThemeSettings(
      preset: preset ?? this.preset,
      accentColor: accentColor ?? this.accentColor,
      primaryColor: primaryColor ?? this.primaryColor,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      fontFamily: fontFamily ?? this.fontFamily,
      skipDuration: skipDuration ?? this.skipDuration,
      volumeStep: volumeStep ?? this.volumeStep,
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
    final defaultTextTheme = ThemeData(brightness: brightness).textTheme;
    final compactTextTheme = defaultTextTheme.copyWith(
      displayLarge: defaultTextTheme.displayLarge?.copyWith(fontSize: (defaultTextTheme.displayLarge?.fontSize ?? 57) * 0.9),
      displayMedium: defaultTextTheme.displayMedium?.copyWith(fontSize: (defaultTextTheme.displayMedium?.fontSize ?? 45) * 0.9),
      displaySmall: defaultTextTheme.displaySmall?.copyWith(fontSize: (defaultTextTheme.displaySmall?.fontSize ?? 36) * 0.9),
      headlineLarge: defaultTextTheme.headlineLarge?.copyWith(fontSize: (defaultTextTheme.headlineLarge?.fontSize ?? 32) * 0.9),
      headlineMedium: defaultTextTheme.headlineMedium?.copyWith(fontSize: (defaultTextTheme.headlineMedium?.fontSize ?? 28) * 0.9),
      headlineSmall: defaultTextTheme.headlineSmall?.copyWith(fontSize: (defaultTextTheme.headlineSmall?.fontSize ?? 24) * 0.9),
      titleLarge: defaultTextTheme.titleLarge?.copyWith(fontSize: (defaultTextTheme.titleLarge?.fontSize ?? 22) * 0.9),
      titleMedium: defaultTextTheme.titleMedium?.copyWith(fontSize: (defaultTextTheme.titleMedium?.fontSize ?? 16) * 0.9),
      titleSmall: defaultTextTheme.titleSmall?.copyWith(fontSize: (defaultTextTheme.titleSmall?.fontSize ?? 14) * 0.9),
      bodyLarge: defaultTextTheme.bodyLarge?.copyWith(fontSize: (defaultTextTheme.bodyLarge?.fontSize ?? 16) * 0.9),
      bodyMedium: defaultTextTheme.bodyMedium?.copyWith(fontSize: (defaultTextTheme.bodyMedium?.fontSize ?? 14) * 0.9),
      bodySmall: defaultTextTheme.bodySmall?.copyWith(fontSize: (defaultTextTheme.bodySmall?.fontSize ?? 12) * 0.9),
      labelLarge: defaultTextTheme.labelLarge?.copyWith(fontSize: (defaultTextTheme.labelLarge?.fontSize ?? 14) * 0.9),
      labelMedium: defaultTextTheme.labelMedium?.copyWith(fontSize: (defaultTextTheme.labelMedium?.fontSize ?? 12) * 0.9),
      labelSmall: defaultTextTheme.labelSmall?.copyWith(fontSize: (defaultTextTheme.labelSmall?.fontSize ?? 11) * 0.9),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: settings.fontFamily,
      textTheme: compactTextTheme,
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

