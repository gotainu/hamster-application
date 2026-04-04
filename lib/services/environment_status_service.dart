class EnvironmentStatusViewData {
  final String stateText;
  final String deltaText;
  final String summaryText;

  const EnvironmentStatusViewData({
    required this.stateText,
    required this.deltaText,
    required this.summaryText,
  });
}

class EnvironmentStatusService {
  const EnvironmentStatusService();

  static const double _tempMin = 20.0;
  static const double _tempMax = 26.0;
  static const double _humMin = 40.0;
  static const double _humMax = 60.0;

  EnvironmentStatusViewData buildTemperatureStatus(double? temp) {
    if (temp == null) {
      return const EnvironmentStatusViewData(
        stateText: '未評価',
        deltaText: '温度データがありません',
        summaryText: '温度データが取得できると状態を表示できます',
      );
    }

    if (temp < _tempMin) {
      final diff = _tempMin - temp;
      return EnvironmentStatusViewData(
        stateText: '低め',
        deltaText: '適正下限より ${diff.toStringAsFixed(1)}℃ 低め',
        summaryText: '温度は低めです。冷えすぎていないか確認したい状態です',
      );
    }

    if (temp > _tempMax) {
      final diff = temp - _tempMax;
      return EnvironmentStatusViewData(
        stateText: '高め',
        deltaText: '適正上限より ${diff.toStringAsFixed(1)}℃ 高め',
        summaryText: '温度は高めです。暑くなりすぎていないか確認したい状態です',
      );
    }

    return const EnvironmentStatusViewData(
      stateText: '理想範囲',
      deltaText: '適正範囲内です',
      summaryText: '温度は適正範囲内で安定しています',
    );
  }

  EnvironmentStatusViewData buildHumidityStatus(double? hum) {
    if (hum == null) {
      return const EnvironmentStatusViewData(
        stateText: '未評価',
        deltaText: '湿度データがありません',
        summaryText: '湿度データが取得できると状態を表示できます',
      );
    }

    if (hum < _humMin) {
      final diff = _humMin - hum;
      return EnvironmentStatusViewData(
        stateText: '低め',
        deltaText: '適正下限より ${diff.round()}pt 低め',
        summaryText: '湿度は低めです。乾燥しすぎていないか見たい状態です',
      );
    }

    if (hum > _humMax) {
      final diff = hum - _humMax;
      return EnvironmentStatusViewData(
        stateText: '高め',
        deltaText: '適正上限より ${diff.round()}pt 高め',
        summaryText: '湿度は高めです。通気や床材のこもりを見直したい状態です',
      );
    }

    return const EnvironmentStatusViewData(
      stateText: '理想範囲',
      deltaText: '適正範囲内です',
      summaryText: '湿度は適正範囲内で安定しています',
    );
  }
}
