import 'package:flutter/material.dart';

/// Schrift der App (JetBrains Mono, liegt in assets/fonts).
const String kMono = 'JetBrainsMono';

/// Farben im TRy-Media Look: fast schwarz, ruhige Grautöne, Orange nur als Akzent.
class AppColors {
  static const background = Color(0xFF111111);
  static const panel = Color(0xFF1A1A1A);
  static const line = Color(0xFF2C2C2C);
  static const empty = Color(0xFF1F1F1F);
  static const text = Color(0xFFECE8E1);
  static const muted = Color(0xFF8E8A84);
  static const thumb = Color(0xFFBDBAB4);
  static const accent = Color(0xFFE8702A);
}

/// Regler Knopf als flache Pille statt Kreis.
class PillThumb extends SliderComponentShape {
  const PillThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 16);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final grow = 2 * activationAnimation.value;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 26 + grow, height: 16 + grow),
      const Radius.circular(8),
    );
    context.canvas.drawRRect(
      r,
      Paint()
        ..color = activationAnimation.value > 0.5
            ? AppColors.text
            : AppColors.thumb,
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: kMono,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.panel,
      onSurface: AppColors.text,
    ),
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.line,
      thumbShape: const PillThumb(),
      overlayShape: SliderComponentShape.noOverlay,
      trackHeight: 2,
      tickMarkShape: SliderTickMarkShape.noTickMark,
      showValueIndicator: ShowValueIndicator.never,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: kMono,
    ),
    iconTheme: const IconThemeData(color: AppColors.text, size: 22),
    dividerColor: AppColors.line,
  );
}
