import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Spacing scale. Everything in the UI snaps to these.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 20.0;
}

abstract final class Radii {
  static const card = 20.0;
  static const field = 14.0;
  static const pill = 999.0;
  static const bar = 4.0;
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = _textTheme(base.textTheme, c);

    return base.copyWith(
      extensions: [c],
      scaffoldBackgroundColor: c.page,
      canvasColor: c.page,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.series1,
        brightness: brightness,
      ).copyWith(
        surface: c.surface,
        onSurface: c.ink,
        primary: c.accent,
        onPrimary: c.onAccent,
        error: c.negative,
        outlineVariant: c.hairline,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: c.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: c.ink, size: 22),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.lg,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: c.inkMuted),
        labelStyle: text.bodySmall?.copyWith(color: c.inkSecondary),
        border: _fieldBorder(Colors.transparent),
        enabledBorder: _fieldBorder(Colors.transparent),
        focusedBorder: _fieldBorder(c.ink.withValues(alpha: 0.45)),
        errorBorder: _fieldBorder(c.negative.withValues(alpha: 0.6)),
        focusedErrorBorder: _fieldBorder(c.negative),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.track,
          disabledForegroundColor: c.inkMuted,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: c.hairline),
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          textStyle: text.labelLarge,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.hairline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? c.ink : c.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? c.ink : c.inkMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.page),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.inkSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.track,
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: color, width: 1.2),
      );

  static TextTheme _textTheme(TextTheme base, AppColors c) {
    return base
        .copyWith(
          // Hero figures. Tight tracking, low weight contrast - the size does
          // the work, not the weight.
          displayLarge: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w300,
            letterSpacing: -1.6,
            height: 1.05,
          ),
          displayMedium: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w400,
            letterSpacing: -1.0,
            height: 1.1,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
          ),
          titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.4),
          bodySmall: const TextStyle(fontSize: 12.5, height: 1.35),
          labelLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          labelMedium: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          // Section eyebrows.
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        )
        .apply(bodyColor: c.ink, displayColor: c.ink);
  }
}
