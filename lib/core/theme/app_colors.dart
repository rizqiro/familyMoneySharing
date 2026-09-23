import 'package:flutter/material.dart';

/// The app's colour system.
///
/// =============================================================================
/// WHAT A ThemeExtension IS, AND WHY THE COLOURS LIVE IN ONE
/// =============================================================================
/// Flutter's own `ThemeData` carries a fixed set of colours (`primary`,
/// `surface`, `error`, ...). Ours needs more than that: a muted ink for
/// captions, a meter track, a hairline, five card tints. A `ThemeExtension` is
/// Flutter's supported way to bolt extra values onto the theme so that:
///
///   * any widget can reach them with `context.colors` (the extension at the
///     bottom of this file), without passing colours down by hand; and
///   * switching between light and dark swaps the whole set at once, with
///     Flutter animating the change through [lerp].
///
/// The rule the palette follows: colour is never decoration. A warm tint marks
/// *which* budget you are looking at; the one strong accent marks *your* money
/// and your own spending line; grey marks your partner's. Everything else is
/// ink on a warm ground.
///
/// =============================================================================
/// WHY THE CHARTS ARE RED AGAINST NEAR-BLACK AND NOT TWO WARM HUES
/// =============================================================================
/// The whole palette is warm - butter through to rose. That is fine for cards,
/// which are labelled. It is not fine for a chart, where two series have to be
/// told apart by colour alone: to a red-green colourblind eye (about 1 man in
/// 12) terracotta and apricot are the same colour.
///
/// So wherever two things must be distinguished, the pair is [series1] (red)
/// against [series2] (near-black) - a *lightness* difference, which survives
/// any kind of colour blindness and a black-and-white screenshot. The budget
/// line on a chart is not a third colour at all; it is drawn dashed.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.isDark,
    required this.page,
    required this.surface,
    required this.surfaceSunken,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.hairline,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.accentDeep,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.series1,
    required this.series2,
    required this.series3,
    required this.track,
  });

  /// Which set of card tints to hand out. Kept as a plain flag rather than a
  /// list field because a `List<Color>` cannot be `const`-compared cheaply and
  /// would make [lerp] noisy for no visual gain.
  final bool isDark;

  final Color page;
  final Color surface;
  final Color surfaceSunken;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color hairline;

  /// The one strong colour. Used for: the selected filter pill, the floating
  /// add button, your own meters, and your spending line on every chart.
  final Color accent;
  final Color onAccent;

  /// A pale wash of the accent, for chips and quiet call-outs. Text on it must
  /// be [onAccentSoft] - the accent itself is too light against it.
  final Color accentSoft;
  final Color onAccentSoft;

  /// A darkened accent, for small text and thin marks that need to clear 4.5:1
  /// on the page ground.
  final Color accentDeep;

  final Color positive;
  final Color negative;
  final Color warning;

  /// Chart series, in fixed order and *never* cycled past slot 3:
  ///   1. your spending (red)
  ///   2. your partner (near-black)
  ///   3. money saved (green)
  /// Read the note at the top of this file before adding a fourth.
  final Color series1;
  final Color series2;
  final Color series3;

  /// Unfilled portion of a progress meter.
  final Color track;

  // ---------------------------------------------------------------- light

  static const light = AppColors(
    isDark: false,
    // A warm off-white rather than pure white. Pure white under a warm palette
    // reads as a blown-out patch; this keeps the whole screen in one family.
    page: Color(0xFFFDFAF5),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF7EFE4),
    // 16.8:1 on the page ground. A warm near-black, not #000 - true black
    // against a cream page looks like a printing error.
    ink: Color(0xFF1C1410),
    inkSecondary: Color(0xFF6B5B4E), // 6.5:1
    // 5.3:1. This carries 11-12px eyebrows and captions; anything lighter
    // falls under the 4.5:1 that small text needs.
    inkMuted: Color(0xFF7A6857),
    hairline: Color(0xFFEFE6DA),
    accent: Color(0xFFBE3A20), // white text on it: 5.6:1
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF7DCD4),
    onAccentSoft: Color(0xFF8F2B18),
    accentDeep: Color(0xFF8F2B18),
    positive: Color(0xFF2E7D4F), // 5.1:1
    negative: Color(0xFFBE3A20),
    warning: Color(0xFFB0521F),
    series1: Color(0xFFBE3A20),
    series2: Color(0xFF3D3028),
    series3: Color(0xFF2E7D4F),
    track: Color(0xFFF2E9DE),
  );

  // ----------------------------------------------------------------- dark

  static const dark = AppColors(
    isDark: true,
    page: Color(0xFF14100E),
    surface: Color(0xFF1F1815),
    surfaceSunken: Color(0xFF191412),
    ink: Color(0xFFFBF4EC),
    inkSecondary: Color(0xFFCBB8A8),
    inkMuted: Color(0xFFA08D7C),
    hairline: Color(0xFF332924),
    // Lighter than the light-mode accent. The same terracotta on a dark ground
    // is too close to the background to read as a highlight, and white text on
    // it would fail contrast - hence the near-black [onAccent] below.
    accent: Color(0xFFE86A4C),
    onAccent: Color(0xFF17100D),
    accentSoft: Color(0xFF3B211A),
    onAccentSoft: Color(0xFFF3A48E),
    accentDeep: Color(0xFFF3A48E),
    positive: Color(0xFF5BBE84),
    negative: Color(0xFFF08A70),
    warning: Color(0xFFE0A05C),
    series1: Color(0xFFE86A4C),
    // The partner series stays the *lighter* of the pair in dark mode, so the
    // red-versus-neutral lightness gap survives the flip.
    series2: Color(0xFFD8C9BC),
    series3: Color(0xFF5BBE84),
    track: Color(0xFF2B221D),
  );

  List<Color> get seriesRamp => [series1, series2, series3];

  // ---------------------------------------------------------------- tints

  /// The five card tints, butter through to rose.
  ///
  /// They are a *ramp*, not a set of meanings: nothing is encoded in "apricot
  /// rather than peach". A budget simply keeps whichever one it is given, so
  /// you learn its colour the way you learn where a shop keeps the milk.
  List<BudgetTint> get tints => isDark ? _darkTints : _lightTints;

  /// Picks a tint for a budget, stably.
  ///
  /// The id's characters are added up and the total taken modulo the number of
  /// tints. That is a (very small) hash: the same id always lands on the same
  /// tint, on both phones, forever, without storing a colour on the budget
  /// document. Reordering the list in a later version would reshuffle every
  /// card - so don't, append instead.
  BudgetTint tintFor(String id) {
    if (id.isEmpty) return tints.first;
    var sum = 0;
    for (final unit in id.codeUnits) {
      sum += unit;
    }
    return tints[sum % tints.length];
  }

  static const _lightTints = <BudgetTint>[
    BudgetTint(fill: Color(0xFFFDF1D6), badge: Color(0xFFF2C14E)),
    BudgetTint(fill: Color(0xFFFCE6CE), badge: Color(0xFFEC9A3C)),
    BudgetTint(fill: Color(0xFFFBDCC6), badge: Color(0xFFE8793C)),
    BudgetTint(fill: Color(0xFFFBD7CE), badge: Color(0xFFE05C3E)),
    BudgetTint(fill: Color(0xFFF9D2D2), badge: Color(0xFFD6453F)),
  ];

  /// The same five hues held at a much lower lightness, so a tinted card still
  /// reads as "that budget" without glowing on a dark screen.
  static const _darkTints = <BudgetTint>[
    BudgetTint(fill: Color(0xFF332711), badge: Color(0xFFF2C14E)),
    BudgetTint(fill: Color(0xFF33250F), badge: Color(0xFFEC9A3C)),
    BudgetTint(fill: Color(0xFF34210F), badge: Color(0xFFE8793C)),
    BudgetTint(fill: Color(0xFF351E14), badge: Color(0xFFE05C3E)),
    BudgetTint(fill: Color(0xFF351A18), badge: Color(0xFFD6453F)),
  ];

  // ------------------------------------------------- ThemeExtension plumbing
  //
  // Both methods below are required by ThemeExtension. They are pure
  // boilerplate: copyWith lets a caller change one value, and lerp is what
  // Flutter calls on every frame of a light/dark transition.

  @override
  AppColors copyWith({
    bool? isDark,
    Color? page,
    Color? surface,
    Color? surfaceSunken,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
    Color? hairline,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? onAccentSoft,
    Color? accentDeep,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? series1,
    Color? series2,
    Color? series3,
    Color? track,
  }) {
    return AppColors(
      isDark: isDark ?? this.isDark,
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      accentDeep: accentDeep ?? this.accentDeep,
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
      // A bool cannot be blended, so it flips at the halfway point.
      isDark: t < 0.5 ? isDark : other.isDark,
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccentSoft: Color.lerp(onAccentSoft, other.onAccentSoft, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
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

/// One card tint: the wash behind the card, and the solid dot that carries its
/// icon.
///
/// Text on a tinted card is always the theme's [AppColors.ink] - the fills are
/// chosen light enough (or dark enough, in dark mode) that it clears 4.5:1 on
/// every one of them.
@immutable
class BudgetTint {
  const BudgetTint({required this.fill, required this.badge});

  final Color fill;
  final Color badge;
}

/// Sugar so any widget can write `context.colors.accent`.
///
/// `Theme.of(context)` walks up the widget tree to the nearest theme;
/// `.extension<AppColors>()` pulls our set out of it. The `!` says "this is
/// never null" - true, because `AppTheme` always installs it.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
