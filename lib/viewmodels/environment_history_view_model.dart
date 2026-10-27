import '../models/environment_history.dart';

/// An initial date on screen is a suggestion, never an answer.
class EnvironmentEffectiveDraft {
  EnvironmentEffectiveDraft(this.displayDate);
  DateTime displayDate;
  EnvironmentEffective? _confirmed;
  bool get confirmed => _confirmed != null;
  bool get unknown => _confirmed?.precision == EnvironmentPrecision.unknown;
  void confirmDate(DateTime day) {
    displayDate = day;
    _confirmed = EnvironmentEffective.dateOnly(
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}');
  }

  void confirmUnknown() => _confirmed = const EnvironmentEffective.unknown();
  void confirmInstant(DateTime time) =>
      _confirmed = EnvironmentEffective.instant(time);
  void restore(EnvironmentEffective effective) {
    _confirmed = effective;
    if (effective.dateKey != null) {
      displayDate = DateTime.parse(effective.dateKey!);
    }
    if (effective.occurredAt != null) {
      displayDate = effective.occurredAt!.toLocal();
    }
  }

  EnvironmentEffective toEffective() =>
      _confirmed ?? (throw StateError('effective_date_not_confirmed'));
}

/// Labels live with the shared history display contract, not in each screen.
class EnvironmentHistoryViewModel {
  const EnvironmentHistoryViewModel(this.entry);
  final EnvironmentHistoryEntry entry;
  static const fields = {
    'cageWidth': 'ケージの横幅',
    'cageDepth': 'ケージの奥行き',
    'cageHeight': 'ケージの高さ',
    'cageFloorArea': 'ケージ底面積',
    'beddingThickness': '床材の深さ',
    'wheelDiameter': '回し車の直径',
    'temperatureControl': '温度の管理',
    'accessoryTags': 'ケージの中にあるもの',
  };
  String get kindLabel => switch (entry.kind) {
        'initial_snapshot' => '現在設定を確認',
        'correction' => '入力の訂正',
        'cancel' => '変更の取消',
        _ => '環境の変更',
      };
  String get effectiveLabel => switch (entry.effective.precision) {
        EnvironmentPrecision.unknown => '変更時期不明',
        EnvironmentPrecision.dateOnly =>
          entry.effective.dateKey!.replaceAll('-', '/'),
        EnvironmentPrecision.instant => _time(entry.effective.occurredAt!),
      };
  String get title => entry.kind == 'initial_snapshot'
      ? kindLabel
      : '$effectiveLabel · $kindLabel';
  String? get beforeCaption => switch (entry.beforeValueMeaning) {
        'previous_day_confirmed_environment' => '前日までの確認値との差分',
        'previous_recorded_input' => '入力値を訂正',
        _ => null,
      };
  List<String> get changeLines => entry.changes.entries
      .map((change) =>
          '${fields[change.key] ?? change.key}　${valueText(change.value.before)} → ${valueText(change.value.after)}')
      .toList();
  List<String> get snapshotLines => entry.values.entries
      .map((field) =>
          '${fields[field.key] ?? field.key}　${valueText(field.value)}')
      .toList();
  String? get acceptedLabel =>
      entry.acceptedAt == null ? null : _time(entry.acceptedAt!);
  static String _time(DateTime time) {
    final local = time.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String valueText(EnvironmentHistoryValue value) {
    if (value.quality == 'invalid') return '確認が必要';
    if (value.quality != 'known' || value.value == null) return '不明';
    final raw = value.value;
    final text = raw is List
        ? (raw.isEmpty ? 'なし' : raw.join('・'))
        : raw is num
            ? (raw == raw.roundToDouble()
                ? raw.toStringAsFixed(0)
                : raw.toString())
            : raw.toString();
    return value.unit == null
        ? text
        : '$text ${value.unit == 'cm2' ? 'cm²' : value.unit}';
  }
}
