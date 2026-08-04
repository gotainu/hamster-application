import 'package:flutter/material.dart';
import '../models/hamster_avatar.dart';
import '../models/semantic_chart_band.dart';
import '../models/sensor_evaluation.dart';
import '../models/anomaly_detection.dart';

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
    return environmentAccent(level).withValues(alpha: opacity);
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

  // ===== Hamster habitat background =====
  // 背景画像・表示濃度・位置・視認性オーバーレイはここへ集約します。
  //
  // 背景の原因判定そのものは HamsterAvatarConditionResolver に集約し、
  // ここでは原因と画像ファイルの対応だけを管理します。
  // これにより、アバターの表情・原因バッジ・背景画像が同じ判定結果を使います。
  static String habitatBackgroundAsset(
    BuildContext context, {
    HamsterAvatarCause cause = HamsterAvatarCause.none,
  }) {
    final isNight = isDark(context);

    switch (cause) {
      case HamsterAvatarCause.heat:
        return isNight
            ? 'assets/images/theme/bg_heat_night.webp'
            : 'assets/images/theme/bg_heat_day.webp';
      case HamsterAvatarCause.cold:
        return isNight
            ? 'assets/images/theme/bg_cold_night.webp'
            : 'assets/images/theme/bg_cold_day.webp';
      case HamsterAvatarCause.humidityHigh:
        return isNight
            ? 'assets/images/theme/bg_humidity_high_night.webp'
            : 'assets/images/theme/bg_humidity_high_day.webp';
      case HamsterAvatarCause.humidityLow:
        return isNight
            ? 'assets/images/theme/bg_humidity_low_night.webp'
            : 'assets/images/theme/bg_humidity_low_day.webp';
      case HamsterAvatarCause.activityHigh:
        return isNight
            ? 'assets/images/theme/bg_activity_high_night.webp'
            : 'assets/images/theme/bg_activity_high_day.webp';
      case HamsterAvatarCause.activityLow:
        return isNight
            ? 'assets/images/theme/bg_activity_low_night.webp'
            : 'assets/images/theme/bg_activity_low_day.webp';
      case HamsterAvatarCause.conditionConcern:
        return isNight
            ? 'assets/images/theme/bg_condition_concern_night.webp'
            : 'assets/images/theme/bg_condition_concern_day.webp';
      case HamsterAvatarCause.insufficientData:
        return isNight
            ? 'assets/images/theme/bg_insufficient_data_night.webp'
            : 'assets/images/theme/bg_insufficient_data_day.webp';
      case HamsterAvatarCause.overallAlert:
        return isNight
            ? 'assets/images/theme/bg_overall_alert_night.webp'
            : 'assets/images/theme/bg_overall_alert_day.webp';
      case HamsterAvatarCause.weightChanged:
        // 現時点では体重変化専用画像がないため、標準背景へ戻します。
        return isNight
            ? 'assets/images/theme/bg_default_night.webp'
            : 'assets/images/theme/bg_default_day.webp';
      case HamsterAvatarCause.none:
        return isNight
            ? 'assets/images/theme/bg_default_night.webp'
            : 'assets/images/theme/bg_default_day.webp';
    }
  }

  // 横長画像をスマートフォンへ cover 表示するため、空を中心に残します。
  static Alignment habitatBackgroundAlignment(BuildContext context) =>
      Alignment.topCenter;

  // 昼・夜それぞれの画像素材側で明るさを調整しているため、
  // アプリ側では減光せず、そのままの発色とコントラストを活かします。
  static double habitatBackgroundOpacity(BuildContext context) => 1.0;

  // 常時ブラーは背景全体を白っぽく霞ませるため無効化します。
  // AppBar／下部ナビ付近の局所ブラーは ScreenEdgeFade が担当します。
  static double habitatBackgroundBlurSigma(BuildContext context) => 0.0;

  // cover表示時の端切れ防止に必要な最小限の拡大だけを残します。
  static const double habitatBackgroundScale = 1.01;

  static Duration get habitatBackgroundTransitionDuration =>
      const Duration(milliseconds: 520);

  static Curve get habitatBackgroundTransitionCurve => Curves.easeOutCubic;

  static Gradient habitatReadabilityOverlay(BuildContext context) {
    final dimColor = Colors.black.withValues(
      alpha: isDark(context) ? 0.2 : 0.3,
    );

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        dimColor,
        dimColor,
      ],
    );
  }

  static Gradient statusCardGradient(
    BuildContext context, {
    required Color accent,
    double strength = 1.0,
  }) {
    final dark = isDark(context);
    final clamped = strength.clamp(0.0, 1.0);

    final base = dark ? darkCard : const Color(0xFFF7F9FC);
    final firstAlpha = dark ? 0.30 * clamped : 0.16 * clamped;
    final secondAlpha = dark ? 0.13 * clamped : 0.06 * clamped;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(accent.withValues(alpha: firstAlpha), base),
        Color.alphaBlend(accent.withValues(alpha: secondAlpha), base),
        base,
      ],
      stops: const [0.0, 0.58, 1.0],
    );
  }

  static BoxDecoration statusCardDecoration(
    BuildContext context, {
    required Color accent,
    double strength = 1.0,
    double radius = 24,
  }) {
    return BoxDecoration(
      gradient: statusCardGradient(
        context,
        accent: accent,
        strength: strength,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accent.withValues(alpha: isDark(context) ? 0.22 : 0.16),
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 18,
          offset: const Offset(0, 9),
          color: softShadow(context),
        ),
      ],
    );
  }

  static BoxDecoration transparentStatusCardDecoration(
    BuildContext context, {
    double radius = 24,
  }) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      // 完全透過カードでは、輪郭線だけでなく外周シャドウも描画しません。
      // 透明な矩形の存在感を消し、背景画像と自然につなげます。
      border: Border.all(color: Colors.transparent),
    );
  }

  static Color sensorStateAccent(MetricState state) {
    switch (state) {
      case MetricState.unknown:
        return const Color(0xFF8A94A6);
      case MetricState.good:
        return envGood;
      case MetricState.caution:
        return envCaution;
      case MetricState.alert:
        return envDanger;
    }
  }

  static Color anomalySeverityAccent(AnomalySeverity severity) {
    switch (severity) {
      case AnomalySeverity.info:
        return const Color(0xFF8A94A6);
      case AnomalySeverity.low:
        return envCaution;
      case AnomalySeverity.medium:
      case AnomalySeverity.high:
        return envDanger;
    }
  }

  // ===== Shared semantic helpers =====
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? Colors.white : lightText;

  static Color secondaryText(BuildContext context) =>
      isDark(context) ? Colors.white70 : const Color(0xFF5F6B7A);

  // ===== Text directly over habitat images =====
  // 背景透過領域専用。通常カード内の配色には影響させません。
  static Color habitatForegroundPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF4A1F2B);

  static Color habitatForegroundSecondary(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.88)
          : const Color(0xFF5E3A45);

  static Color habitatForegroundMuted(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.76)
      : const Color(0xFF6E5660);

  static List<Shadow> habitatForegroundShadows(BuildContext context) {
    if (isDark(context)) {
      return [
        Shadow(
          color: Colors.black.withValues(alpha: 0.72),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.36),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];
    }

    return [
      Shadow(
        color: Colors.white.withValues(alpha: 0.96),
        blurRadius: 8,
      ),
      Shadow(
        color: Colors.white.withValues(alpha: 0.72),
        blurRadius: 3,
      ),
      Shadow(
        color: Colors.black.withValues(alpha: 0.14),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  // ===== Transparent overall-condition hero =====
  // 背景画像の上へ直接表示する総合コンディション領域専用です。
  // ライト／ダークを問わず白系へ統一し、状態色は背景画像や文言で伝えます。
  static Color overallConditionForeground(BuildContext context) => Colors.white;

  static Color overallConditionSecondary(BuildContext context) =>
      Colors.white.withValues(alpha: 0.92);

  static Color overallConditionMuted(BuildContext context) =>
      Colors.white.withValues(alpha: 0.82);

  static Color overallConditionGaugeTrack(BuildContext context) =>
      Colors.white.withValues(alpha: 0.24);

  static Color overallConditionChartGrid(BuildContext context) =>
      Colors.white.withValues(alpha: 0.22);

  static Color overallConditionPointFill(BuildContext context) =>
      Colors.white.withValues(alpha: 0.16);

  static List<Shadow> overallConditionForegroundShadows(
    BuildContext context,
  ) =>
      [
        Shadow(
          color: Colors.black.withValues(alpha: 0.76),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        Shadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static Color tertiaryText(BuildContext context) =>
      isDark(context) ? Colors.white54 : const Color(0xFF7E8896);

  static Color weakText(BuildContext context) =>
      isDark(context) ? Colors.white38 : const Color(0xFF9AA3AF);

  static Color softBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.08);

  static Color softShadow(BuildContext context) =>
      isDark(context) ? const Color(0x1A000000) : const Color(0x12000000);

  static Color chipFill(Color accentColor, BuildContext context,
      {double? opacity}) {
    final value = opacity ?? (isDark(context) ? 0.12 : 0.10);
    return accentColor.withValues(alpha: value);
  }

  static Color chartAxis(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.25)
      : Colors.black.withValues(alpha: 0.22);

  static Color chartGrid(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);

  static Color cardSurface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color heroDecorationFill(
    BuildContext context,
    Color accentColor, {
    double darkOpacity = 0.10,
    double lightOpacity = 0.08,
  }) {
    return accentColor.withValues(
      alpha: isDark(context) ? darkOpacity : lightOpacity,
    );
  }

  static Color heroPetIcon(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);

  static Color quickActionFill(BuildContext context) =>
      accent.withValues(alpha: isDark(context) ? 0.09 : 0.08);

  static Color quickActionBorder(BuildContext context) =>
      accent.withValues(alpha: isDark(context) ? 0.18 : 0.14);

  // ===== Transparent AppBar / screen-edge fade =====
  static Color overlayAppBarForeground(BuildContext context) => Colors.white;

  static Color screenEdgeFadeTint(BuildContext context) =>
      isDark(context) ? const Color(0xA8121721) : const Color(0xA6151C27);

  // AppBarの内側へ約30%入るまでは、ブラーも暗転も始めません。
  static const double screenEdgeTopClearFraction = 0.30;

  // 下側は既存の見え方を維持します。
  static const double screenEdgeBottomClearFraction = 0.06;

  // ===== Habitat glass drawer =====
  static const double drawerBlurSigma = 18.0;

  static Color drawerSurface(BuildContext context) => isDark(context)
      ? const Color.fromARGB(124, 18, 25, 36)
      : const Color.fromARGB(111, 247, 249, 252);

  static Color drawerOuterBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.16)
      : const Color(0xFF243C5A).withValues(alpha: 0.12);

  static Gradient drawerStatusBarOverlay(BuildContext context) {
    final color = isDark(context)
        ? Colors.black.withValues(alpha: 0.22)
        : const Color(0xFF183044).withValues(alpha: 0.42);

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color,
        Colors.transparent,
      ],
    );
  }

  static Color drawerGroupSurface(BuildContext context) => isDark(context)
      ? const Color(0xFF222A38).withValues(alpha: 0.9)
      : Colors.white.withValues(alpha: 0.8);

  static Color drawerGroupBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.15)
      : const Color(0xFF243C5A).withValues(alpha: 0.14);

  static List<BoxShadow> drawerGroupShadows(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: isDark(context) ? 0.18 : 0.08,
          ),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ];

  static Color drawerHeaderIconSurface(BuildContext context) =>
      Colors.white.withValues(alpha: isDark(context) ? 0.10 : 0.62);

  static Color drawerHeaderIconBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.22)
      : const Color(0xFF27435F).withValues(alpha: 0.16);

  static Color drawerItemIconSurface(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.075)
      : const Color(0xFF23405F).withValues(alpha: 0.07);

  static Color drawerItemIconBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.18)
      : const Color(0xFF23405F).withValues(alpha: 0.16);

  static Color drawerIconForeground(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF27435F);

  static Color drawerPrimaryText(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF1D2935);

  static Color drawerSecondaryText(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.74)
      : const Color(0xFF526273);

  static Color drawerSectionLabel(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.76)
      : const Color(0xFF4B5C6E);

  static Color drawerChevron(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.50)
      : const Color(0xFF506174).withValues(alpha: 0.82);

  static Color drawerDivider(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.10)
      : const Color(0xFF243C5A).withValues(alpha: 0.11);

  static Color drawerInteractionFill(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.07)
      : const Color(0xFF27435F).withValues(alpha: 0.065);

  static Color drawerFooterText(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.48)
      : const Color(0xFF526170).withValues(alpha: 0.88);

  // ===== Floating navigation / quick record sheet =====
  static Color floatingNavigationSurface(BuildContext context) =>
      isDark(context) ? const Color(0xEB30343B) : const Color(0xF2FFFFFF);

  static Color floatingNavigationBorder(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.13)
      : Colors.black.withValues(alpha: 0.08);

  static Color floatingNavigationSelected(BuildContext context) =>
      isDark(context) ? Colors.white : accent;

  static Color floatingNavigationUnselected(BuildContext context) =>
      isDark(context) ? Colors.white60 : const Color(0xFF66717F);

  static Color floatingNavigationLabel(BuildContext context) =>
      floatingNavigationUnselected(context);

  // 選択状態はアイコン色だけで表現し、背景の塗り分けは行いません。
  static Color floatingNavigationSelectedFill(BuildContext context) =>
      Colors.transparent;

  static Color floatingRecordButtonSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF34383F) : const Color(0xFFFFFFFF);

  static Color quickRecordSheetSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF20242D) : const Color(0xFFF6F8FB);

  static List<BoxShadow> floatingNavigationShadows(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: isDark(context) ? 0.34 : 0.16,
          ),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ];

  static Color chartGlow(Color base, BuildContext context) =>
      base.withValues(alpha: isDark(context) ? 0.18 : 0.14);

  static Color emptyStateFill(BuildContext context, Color accentColor) =>
      accentColor.withValues(alpha: isDark(context) ? 0.08 : 0.06);

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
            color:
                isDark ? Colors.black.withValues(alpha: 0.22) : Colors.black12,
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
      hintStyle: TextStyle(color: lightText.withValues(alpha: 0.4)),
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
