import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Primary & Accent Color
  static const Color primaryColor = Color(0xFFFF5722); // Vibrant Ember Orange
  static const Color primaryGradientEnd = Color(0xFFFF8F00); // Warm Sunset Glow
  static const Color primaryLight = Color(0xFFFF7D47);
  static const Color primaryDark = Color(0xFFD84315);
  static const Color secondaryColor = Color(0xFF38BDF8); // Soft Electric Sky

  static LinearGradient get primaryGradient => const LinearGradient(
        colors: [primaryColor, primaryGradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Risk Color System
  static const Color lowRiskColor = Color(0xFF10B981); // Emerald Mint
  static const Color moderateRiskColor = Color(0xFFF59E0B); // Amber
  static const Color highRiskColor = Color(0xFFEF4444); // Crimson

  // ---------------------------------------------------------------------------
  // OLED True Dark Palette (#000000 / #0A0A0A base, no bluish tint)
  // ---------------------------------------------------------------------------
  static const Color darkBg = Color(0xFF0A0A0A); // True OLED dark background
  static const Color darkSurface = Color(0xFF121212); // Tonal Surface 1 (Cards, Dialogs)
  static const Color darkSurfaceHigh = Color(0xFF1A1A1A); // Tonal Surface 2 (Input fields, Chips)
  static const Color darkSurfaceHighest = Color(0xFF262626); // Tonal Surface 3 (Borders, Dividers)

  // Contrast Text Tokens (Material Guidelines)
  static const Color textPrimaryDark = Color(0xDEFFFFFF); // ~87% opacity white
  static const Color textSecondaryDark = Color(0x99FFFFFF); // ~60% opacity white
  static const Color textTertiaryDark = Color(0x61FFFFFF); // ~38% opacity white

  // ---------------------------------------------------------------------------
  // Light Palette (Warm Sunset Cream)
  // ---------------------------------------------------------------------------
  static const Color lightBg = Color(0xFFFAF7F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFF3EDE4);
  static const Color lightSurfaceHighest = Color(0xFFE7DDCF);

  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF666666);

  static const double borderRadiusValue = 14.0;
  static final BorderRadius commonRadius = BorderRadius.circular(borderRadiusValue);

  static final String? defaultFontFamily = GoogleFonts.outfit().fontFamily;

  // ---------------------------------------------------------------------------
  // PRODUCTION-READY OLED TRUE DARK THEME
  // ---------------------------------------------------------------------------
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    fontFamily: defaultFontFamily,

    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF4A1504),
      onPrimaryContainer: Color(0xFFFFDBCD),
      secondary: secondaryColor,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF033B5B),
      onSecondaryContainer: Color(0xFFCBE7FF),
      surface: darkSurface,
      onSurface: textPrimaryDark,
      surfaceContainerLowest: Color(0xFF050505),
      surfaceContainerLow: Color(0xFF0E0E0E),
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkSurfaceHigh,
      surfaceContainerHighest: darkSurfaceHighest,
      onSurfaceVariant: textSecondaryDark,
      error: highRiskColor,
      onError: Colors.white,
      errorContainer: Color(0xFF410E0B),
      onErrorContainer: Color(0xFFF9DEDC),
      outline: darkSurfaceHighest,
      outlineVariant: Color(0xFF333333),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE6E6E6),
      onInverseSurface: Color(0xFF1F1F1F),
      inversePrimary: primaryDark,
    ),



    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimaryDark),
      actionsIconTheme: IconThemeData(color: textPrimaryDark),
      
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: commonRadius,
        side: const BorderSide(color: darkSurfaceHighest, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: darkSurfaceHighest,
        disabledForegroundColor: textTertiaryDark,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: commonRadius),

      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimaryDark,
        side: const BorderSide(color: darkSurfaceHighest, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: commonRadius),

      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textPrimaryDark,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),


      border: OutlineInputBorder(
        borderRadius: commonRadius,
        borderSide: const BorderSide(color: darkSurfaceHighest),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: commonRadius,
        borderSide: const BorderSide(color: darkSurfaceHighest),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: commonRadius,
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: commonRadius,
        borderSide: const BorderSide(color: highRiskColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: commonRadius,
        borderSide: const BorderSide(color: highRiskColor, width: 2),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: darkSurfaceHighest),
      ),


    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      modalBackgroundColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: primaryColor.withValues(alpha: 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor);
        }
        return const IconThemeData(color: textSecondaryDark);
      }),

    ),

    popupMenuTheme: PopupMenuThemeData(
      color: darkSurfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: commonRadius,
        side: const BorderSide(color: darkSurfaceHighest),
      ),

    ),

    chipTheme: ChipThemeData(
      backgroundColor: darkSurfaceHigh,
      disabledColor: darkBg,
      selectedColor: primaryColor,
      secondarySelectedColor: primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),


      brightness: Brightness.dark,
      side: const BorderSide(color: darkSurfaceHighest),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: darkSurfaceHigh,
      iconColor: textSecondaryDark,
      textColor: textPrimaryDark,
      shape: RoundedRectangleBorder(borderRadius: commonRadius),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return textSecondaryDark;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return darkSurfaceHighest;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: darkSurfaceHighest, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryColor;
        return textSecondaryDark;
      }),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSurfaceHigh,

      actionTextColor: primaryColor,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: commonRadius),
      behavior: SnackBarBehavior.floating,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryColor,
      linearTrackColor: darkSurfaceHighest,
      circularTrackColor: darkSurfaceHighest,
    ),

    dividerTheme: const DividerThemeData(
      color: darkSurfaceHighest,
      thickness: 1,
      space: 1,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: darkSurfaceHighest,
        borderRadius: BorderRadius.circular(8),
      ),

    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(darkSurfaceHighest),
      radius: const Radius.circular(8),
      thickness: WidgetStateProperty.all(6),
    ),
  );

  // ---------------------------------------------------------------------------
  // LIGHT THEME
  // ---------------------------------------------------------------------------
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    fontFamily: defaultFontFamily,

    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFDBCD),
      onPrimaryContainer: Color(0xFF3B0900),
      secondary: secondaryColor,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE0F2FE),
      onSecondaryContainer: Color(0xFF0369A1),
      surface: lightSurface,
      onSurface: textPrimaryLight,
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAF6F2),
      surfaceContainer: lightSurface,
      surfaceContainerHigh: lightSurfaceHigh,
      surfaceContainerHighest: lightSurfaceHighest,
      onSurfaceVariant: textSecondaryLight,
      error: highRiskColor,
      onError: Colors.white,
      outline: lightSurfaceHighest,
      shadow: Colors.black12,
    ),



    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textPrimaryLight),

    ),

    cardTheme: CardThemeData(
      color: lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: commonRadius,
        side: const BorderSide(color: lightSurfaceHigh),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 1,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: commonRadius),

      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: commonRadius, borderSide: const BorderSide(color: lightSurfaceHighest)),
      enabledBorder: OutlineInputBorder(borderRadius: commonRadius, borderSide: const BorderSide(color: lightSurfaceHighest)),
      focusedBorder: OutlineInputBorder(borderRadius: commonRadius, borderSide: const BorderSide(color: primaryColor, width: 2)),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimaryLight,

      shape: RoundedRectangleBorder(borderRadius: commonRadius),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

