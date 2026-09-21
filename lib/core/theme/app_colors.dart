import 'package:flutter/material.dart';

/// Flat, quiet palette: one ink, one surface, a hairline, and colour used only
/// where it carries meaning (money in / money out / chart series).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.surface,
    required this.surfaceSunken,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.series1,
    required this.series2,
    required this.series3,
    required this.track,
  });

  final Color page;
  final Color surface;
  final Color surfaceSunken;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color hairline;
  final Color accent;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color warning;

  /// Categorical chart slots, in fixed order. Never cycle past slot 3 - fold
  /// the remainder into "Other" instead.
  final Color series1;
  final Color series2;
  final Color series3;

  /// Unfilled portion of a progress meter.
  final Color track;

  static const light = AppColors(
    page: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF1F1EE),
    ink: Color(0xFF0B0B0B),
    inkSecondary: Color(0xFF52514E),
    inkMuted: Color(0xFF898781),
    hairline: Color(0xFFE6E5E0),
    accent: Color(0xFF0B0B0B),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF006300),
    negative: Color(0xFFD03B3B),
    warning: Color(0xFFEC835A),
    series1: Color(0xFF2A78D6),
    series2: Color(0xFFEB6834),
    series3: Color(0xFF1BAF7A),
    track: Color(0xFFEDECE8),
  );

  static const dark = AppColors(
    page: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1A19),
    surfaceSunken: Color(0xFF141413),
    ink: Color(0xFFFFFFFF),
    inkSecondary: Color(0xFFC3C2B7),
    inkMuted: Color(0xFF898781),
    hairline: Color(0xFF2C2C2A),
    accent: Color(0xFFFFFFFF),
    onAccent: Color(0xFF0B0B0B),
    positive: Color(0xFF0CA30C),
    negative: Color(0xFFE66767),
    warning: Color(0xFFEC835A),
    series1: Color(0xFF3987E5),
    series2: Color(0xFFD95926),
    series3: Color(0xFF199E70),
    track: Color(0xFF2C2C2A),
  );

  List<Color> get seriesRamp => [series1, series2, series3];

  @override
  AppColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceSunken,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? hairline,
    Color? accent,
    Color? onAccent,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? series1,
    Color? series2,
    Color? series3,
    Color? track,
  }) {
    return AppColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      series1: series1 ?? this.series1,
      series2: series2 ?? this.series2,
      series3: series3 ?? this.series3,
      track: track ?? this.track,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      series1: Color.lerp(series1, other.series1, t)!,
      series2: Color.lerp(series2, other.series2, t)!,
      series3: Color.lerp(series3, other.series3, t)!,
      track: Color.lerp(track, other.track, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
