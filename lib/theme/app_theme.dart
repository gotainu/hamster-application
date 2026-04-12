import 'package:flutter/material.dart';
import '../models/semantic_chart_band.dart';

class AppTheme {
  // ===== Environment Assessment Visual =====
  static const Color envGood = Color(0xFF4CD6A7);
  static const Color envCaution = Color(0xFFFFC857);
  static const Color envCautionLight = Color(0xFFB77900);
  static const Color envDanger = Color(0xFFFF6B6B);

  static Gradient environmentHeroGradient(String? level, {bool isDark = true}) {
    switch (level) {
      case '良好':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF163B3A),
                  Color(0xFF1E4E59),
                  Color(0xFF2A2E4A),
                ]
              : const [
                  Color(0xFFDDFBF2),
                  Color(0xFFCDEEF7),
                  Color(0xFFEFF4FF),
                ],
        );
      case '危険':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF4A1F26),
                  Color(0xFF452B39),
                  Color(0xFF2A2438),
                ]
              : const [
                  Color(0xFFFFE2E2),
                  Color(0xFFFFECE5),
                  Color(0xFFF8F1F4),
                ],
        );
      case '注意':
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF4B3A1E),
                  Color(0xFF2F3C59),
                  Color(0xFF252A40),
                ]
              : const [
                  Color(0xFFFFF2CC),
                  Color(0xFFDCEBFF),
                  Color(0xFFF1F4FA),
                ],
        );
    }
  }

  static Color environmentAccent(String? level) {
    switch (level) {
      case '良好':
        return envGood;
      case '危険':
        return envDanger;
      case '注意':
      default:
        return envCaution;
    }
  }

  static Color environmentAccentForContext(
    BuildContext context,
    String? level,
  ) {
    final dark = isDark(context);

    switch (level) {
      case '良好':
        return envGood;
      case '危険':
        return envDanger;
      case '注意':
      default:
        return dark ? envCaution : envCautionLight;
    }
  }

  static Color environmentSoftFill(String? level, {double opacity = 0.16}) {
    return environmentAccent(level).withOpacity(opacity);
  }

  // ---- グラデーションカラー（OuraRing風） ----
  static const Color gradientStart = Color(0xFF263C70);
  static const Color gradientEnd = Color(0xFF181A20);
  static const Color cardGradientStart = Color(0xFF232E47);
  static const Color cardGradientEnd = Color(0xFF202638);
  static const Color accent = Color.fromARGB(255, 73, 125, 246);

  // ダークテーマの色
  static const Color darkBg = gradientEnd;
  static const Color darkCard = Color(0xFF232635);
  static const Color cardInnerDark = Color(0xFF292B3E);
  static const Color cardTextColor = Colors.white70;
  static const Gradient darkBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF20253C),
      Color(0xFF181A20),
    ],
  );

  // ライトテーマの色
  static const Color lightBg = Color(0xFFF4F7FB);
  static const Color lightCard = Color(0xFFE7EBF7);
  static const Color cardInnerLight = Color(0xFFE5EAF6);
  static const Color lightText = Color(0xFF263238);
  static const Gradient lightBgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(255, 242, 244, 248),
      Color.fromARGB(255, 183, 193, 211),
    ],
  );

  // ===== Shared semantic helpers =====
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? Colors.white : lightText;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? Colors.white70 : const Color(0xFF5F6B7A);

  static Color tertiaryText(BuildContext context) =>
      isDark(context) ? Colors.white54 : const Color(0xFF7E8896);

  static Color weakText(BuildContext context) =>
      isDark(context) ? Colors.white38 : const Color(0xFF9AA3AF);

  static Color softBorder(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.14)
      : Colors.black.withOpacity(0.08);

  static Color softShadow(BuildContext context) =>
      isDark(context) ? const Color(0x1A000000) : const Color(0x12000000);

  static Color chipFill(Color accentColor, BuildContext context,
      {double? opacity}) {
    final value = opacity ?? (isDark(context) ? 0.12 : 0.10);
    return accentColor.withOpacity(value);
  }

  static Color chartAxis(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.25)
      : Colors.black.withOpacity(0.22);

  static Color chartGrid(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.08);

  static Color cardSurface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color heroDecorationFill(
    BuildContext context,
    Color accentColor, {
    double darkOpacity = 0.10,
    double lightOpacity = 0.08,
  }) {
    return accentColor.withOpacity(
      isDark(context) ? darkOpacity : lightOpacity,
    );
  }

  static Color heroPetIcon(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.05)
      : Colors.black.withOpacity(0.04);

  static Color quickActionFill(BuildContext context) =>
      accent.withOpacity(isDark(context) ? 0.09 : 0.08);

  static Color quickActionBorder(BuildContext context) =>
      accent.withOpacity(isDark(context) ? 0.18 : 0.14);

  static Color chartGlow(Color base, BuildContext context) =>
      base.withOpacity(isDark(context) ? 0.18 : 0.14);

  static Color emptyStateFill(BuildContext context, Color accentColor) =>
      accentColor.withOpacity(isDark(context) ? 0.08 : 0.06);

  static Color semanticBandColor(
    BuildContext context,
    SemanticBandKey bandKey,
  ) {
    switch (bandKey) {
      case SemanticBandKey.low:
        return sparkBandLow(context);
      case SemanticBandKey.high:
        return sparkBandHigh(context);
      case SemanticBandKey.normal:
        return sparkBandNormal(context);
    }
  }

  // ===== Spark / Distribution colors =====
  static Color sparkBandLow(BuildContext context) =>
      isDark(context) ? const Color(0x142D7FF9) : const Color(0x1F7FB3FF);

  static Color sparkBandNormal(BuildContext context) =>
      isDark(context) ? const Color(0x142CD67A) : const Color(0x1F4CD6A7);

  static Color sparkBandHigh(BuildContext context) =>
      isDark(context) ? const Color(0x14FFB84D) : const Color(0x24FFC857);

  static Color histogramBar(BuildContext context) => isDark(context)
      ? const Color.fromARGB(255, 136, 125, 1)
      : const Color(0xFFC6B84A);

  static Color histogramBarHighlight(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFF176) : const Color(0xFFFFD54F);

  // ------ グラデ付きテーマ拡張 ------
  static BoxDecoration backgroundGradient([bool isDark = true]) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              isDark ? [gradientStart, gradientEnd] : [lightBg, Colors.white],
        ),
      );

  static BoxDecoration cardGradient([bool isDark = true]) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [cardGradientStart, cardGradientEnd]
              : [lightCard, Colors.white],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.22) : Colors.black12,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );

  // ダークテーマ
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'NotoSans',
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: Color.fromARGB(122, 73, 125, 246),
      secondary: Colors.white,
      surface: darkCard,
    ),
    cardColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF24273B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: Colors.white38),
      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    ),
    cardTheme: const CardThemeData(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24))),
      margin: EdgeInsets.all(16),
      elevation: 0,
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: accent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
  );

  // ライトテーマ
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'NotoSans',
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: Color.fromARGB(139, 73, 125, 246),
      secondary: Colors.black87,
      surface: lightCard,
    ),
    cardColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: lightText,
      iconTheme: IconThemeData(color: accent),
      titleTextStyle: TextStyle(
        color: lightText,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: lightText),
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF263238)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEFEFF5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: lightText.withOpacity(0.4)),
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    ),
    cardTheme: const CardThemeData(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24))),
      margin: EdgeInsets.all(16),
      elevation: 0,
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: accent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
  );
}
