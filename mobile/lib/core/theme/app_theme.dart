// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_visual_mode.dart';
import 'cosmo_theme_tokens.dart';
import 'nebula_alpha.dart';
import 'nebula_colors.dart';
import 'nebula_tokens.dart';

class AppTheme {
  static const themeExtensions = <ThemeExtension<dynamic>>[
    CosmoThemeTokens.darkInternals,
  ];

  static ThemeData get dark => darkInternals;

  static ThemeData get darkInternals {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: NebulaColors.deepVoid,
      colorScheme: const ColorScheme.dark(
        primary: NebulaColors.stellarBlue,
        secondary: NebulaColors.nebulaPurple,
        surface: NebulaColors.spaceBlack,
        error: NebulaColors.errorRose,
        onPrimary: NebulaColors.softWhite,
        onSecondary: NebulaColors.softWhite,
        onSurface: NebulaColors.softWhite,
      ),
      textTheme: _buildTextTheme(useGlow: true),
      extensions: themeExtensions,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceMono',
          color: NebulaColors.softWhite,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: NebulaColors.softWhite),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: NebulaColors.spaceBlack,
        selectedItemColor: NebulaColors.stellarBlue,
        unselectedItemColor: NebulaColors.ghostText,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NebulaColors.nebulaSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: const BorderSide(color: NebulaColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: const BorderSide(color: NebulaColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide:
              const BorderSide(color: NebulaColors.auroraCyan, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: const BorderSide(color: NebulaColors.errorRose),
        ),
        labelStyle:
            TextStyle(fontFamily: 'SpaceMono', color: NebulaColors.dimText),
        hintStyle:
            TextStyle(fontFamily: 'SpaceMono', color: NebulaColors.ghostText),
        prefixIconColor: NebulaColors.dimText,
        suffixIconColor: NebulaColors.dimText,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      // Phase 2 StellarButton replaces ElevatedButton — this is a safe fallback
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NebulaColors.stellarBlue,
          foregroundColor: NebulaColors.softWhite,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          ),
          textStyle: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: NebulaColors.spaceBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusLG),
          side: const BorderSide(color: NebulaColors.surfaceBorder),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: NebulaColors.surfaceBorder,
        thickness: 1,
      ),
    );
  }

  static ThemeData get lightShader =>
      _buildLightPlaceholder(CosmoThemeTokens.lightShader);

  static ThemeData get lightLite =>
      _buildLightPlaceholder(CosmoThemeTokens.lightLite);

  static ThemeMode themeModeFor(AppVisualMode visualMode) {
    return switch (visualMode) {
      AppVisualMode.darkInternals => ThemeMode.dark,
      AppVisualMode.lightShader => ThemeMode.light,
      AppVisualMode.lightLite => ThemeMode.light,
    };
  }

  static ThemeData lightThemeFor(AppVisualMode visualMode) {
    return switch (visualMode) {
      AppVisualMode.lightShader => lightShader,
      _ => lightLite,
    };
  }

  static ThemeData _buildLightPlaceholder(CosmoThemeTokens tokens) {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: tokens.background,
      colorScheme: ColorScheme.light(
        primary: tokens.primaryAccent,
        secondary: tokens.secondaryAccent,
        surface: tokens.surface,
        error: tokens.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: tokens.primaryText,
      ),
      textTheme: _buildTextTheme(useGlow: false).apply(
        bodyColor: tokens.primaryText,
        displayColor: tokens.primaryText,
      ),
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: tokens.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: tokens.primaryText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: BorderSide(color: tokens.focusAccent, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          borderSide: BorderSide(color: tokens.error),
        ),
        labelStyle: TextStyle(color: tokens.mutedText),
        hintStyle:
            TextStyle(color: tokens.mutedText.withValues(alpha: NebulaAlpha.high)),
        prefixIconColor: tokens.mutedText,
        suffixIconColor: tokens.mutedText,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primaryAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NebulaTokens.radiusLG),
          side: BorderSide(color: tokens.surfaceBorder),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: tokens.surfaceBorder,
        thickness: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme({required bool useGlow}) {
    const glowShadow = Shadow(
      color: Color(0x9900FFCC), // auroraCyan with opacity
      blurRadius: 4.0,
    );
    final shadows = useGlow ? const [glowShadow] : null;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        shadows: shadows,
      ),
      displayMedium: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        shadows: shadows,
      ),
      displaySmall: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        shadows: shadows,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        shadows: shadows,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        shadows: shadows,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        shadows: shadows,
      ),
      titleLarge: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.dimText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 16,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.dimText,
        fontSize: 14,
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.ghostText,
        fontSize: 12,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.softWhite,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      labelMedium: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.dimText,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
      labelSmall: TextStyle(
        fontFamily: 'SpaceMono',
        color: NebulaColors.ghostText,
        fontSize: 10,
        letterSpacing: 0.2,
      ),
    );
  }
}
