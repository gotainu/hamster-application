import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // dart-define を最優先、なければ .env
  static String get switchBotToken =>
      const String.fromEnvironment('SWITCHBOT_TOKEN', defaultValue: '')
          .ifEmpty(dotenv.env['SWITCHBOT_TOKEN'] ?? '');

  static String get switchBotSecret =>
      const String.fromEnvironment('SWITCHBOT_SECRET', defaultValue: '')
          .ifEmpty(dotenv.env['SWITCHBOT_SECRET'] ?? '');

  static bool get isConfigured =>
      switchBotToken.isNotEmpty && switchBotSecret.isNotEmpty;
}

// 小さな拡張：空文字なら別値にフォールバック
extension _StrX on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
