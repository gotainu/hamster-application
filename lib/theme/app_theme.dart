import 'package:flutter/material.dart';

class AppTheme {
  // ---- グラデーションカラー（OuraRing風） ----
  static const Color gradientStart = Color(0xFF263C70); // 深めの青
  static const Color gradientEnd = Color(0xFF181A20); // 黒に近い
  static const Color cardGradientStart = Color(0xFF232E47); // カード上部
  static const Color cardGradientEnd = Color(0xFF202638); // カード下部
  static const Color accent = Color.fromARGB(255, 73, 125, 246); // ボタン青

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
    cardColor: Colors.transparent, // ← カードもグラデで描くのでtransparent
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
      color: Colors.transparent, // グラデ用
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
    cardColor: Colors.transparent, // グラデで描く
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
