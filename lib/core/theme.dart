import 'package:flutter/material.dart';

/// Centrální barevnost a témata AlphaLiftu.
///
/// Paleta: hluboká černá + elektrická modrá. Všechny obrazovky tahají
/// barvy odsud, takže změna tady se propíše do celé aplikace.
class AppTheme {
  AppTheme._();

  // ---------- Barvy ----------
  static const accent = Color(0xFF4C8DFF);
  static const accentBright = Color(0xFF8AB8FF);
  static const cyan = Color(0xFF43D9FF);

  static const bg = Color(0xFF06080D);
  static const surface = Color(0xFF10151E);
  static const surfaceHigh = Color(0xFF171E2A);
  static const surfaceHighest = Color(0xFF212B3A);
  static const outline = Color(0xFF283344);

  static const textMuted = Color(0xFF93A0B4);
  static const success = Color(0xFF3DDC97);
  static const danger = Color(0xFFFF5C6C);

  // ---------- Gradienty ----------
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16233A), Color(0xFF0E1521), Color(0xFF0B0F17)],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6FA8FF), Color(0xFF2F6BFF)],
  );

  static const barGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5FA0FF), Color(0xFF2F6BFF)],
  );

  static const avatarColors = <Color>[
    Color(0xFF3D8BFF),
    Color(0xFF5B6CFF),
    Color(0xFF2FA8FF),
    Color(0xFF6D7DFF),
    Color(0xFF2C4A8A),
    Color(0xFF42526B),
  ];

  static Color avatarColor(String name) =>
      avatarColors[name.hashCode.abs() % avatarColors.length];

  // ---------- Téma ----------
  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF1B2C4D),
      onPrimaryContainer: const Color(0xFFD8E6FF),
      secondary: cyan,
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFF16263E),
      onSecondaryContainer: const Color(0xFFCFE2FF),
      error: danger,
      onError: Colors.white,
      surface: bg,
      onSurface: const Color(0xFFF2F6FF),
      onSurfaceVariant: textMuted,
      outline: outline,
      outlineVariant: const Color(0xFF1B2432),
      surfaceContainerLowest: const Color(0xFF04060A),
      surfaceContainerLow: const Color(0xFF0A0E15),
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
    );

    final onSurface = scheme.onSurface;
    final baseText = ThemeData.dark(useMaterial3: true).textTheme.apply(
          bodyColor: onSurface,
          displayColor: onSurface,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      textTheme: baseText.copyWith(
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.07),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: onSurface.withValues(alpha: 0.88)),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Pozor: Size.fromHeight = nekonečná šířka. Je to záměr pro
          // full-width tlačítka v Column/ListView. V Row vždy nastav
          // vlastní konečný minimumSize!
          minimumSize: const Size.fromHeight(52),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accent.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBright,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF090D14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: accent.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accentBright : textMuted,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accentBright : textMuted,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHighest,
        contentTextStyle: TextStyle(
          color: onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: accentBright,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: accent,
        disabledColor: surfaceHigh,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: textMuted,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return surfaceHigh;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return textMuted;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
    );
  }
}
