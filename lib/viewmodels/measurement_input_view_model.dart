import 'package:cloud_functions/cloud_functions.dart';
import '../models/weight_record.dart';

/// Display formatting stays separate from the authoritative repository payload.
class MeasurementInputViewModel {
  static String formatWeight(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  static String formatDistance(double? meters) {
    if (meters == null) return '-';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(2)} km';
    return '${meters.toStringAsFixed(0)} m';
  }

  static String? weightComparison(WeightRecord record, WeightRecord? previous) {
    if (previous == null) return null;
    final difference = record.weightGrams - previous.weightGrams;
    if (difference.abs() < 0.05) return '前回と同じ体重です';
    final sign = difference > 0 ? '+' : '';
    return '前回比 $sign${difference.toStringAsFixed(1)}g';
  }

  static String? timingChoice(Map<String, dynamic>? timing,
      {bool activity = false}) {
    if (timing == null) return null;
    if (activity &&
        timing['windowMeaning'] == 'selected_night_to_next_morning') {
      return 'night';
    }
    final precision = timing['precision'] ?? timing['timePrecision'];
    if (precision == 'instant') return 'instant';
    return precision == 'date_only'
        ? (activity ? 'day' : 'date_only')
        : 'unknown';
  }

  static String failureMessage(Object error) {
    if (error is FirebaseFunctionsException &&
        (error.code == 'aborted' || error.code == 'already-exists')) {
      return '別の保存や同じ日付の記録と競合しました。入力を残しています。最新の記録を確認してください。';
    }
    if (error is StateError &&
        error.message == 'measurement_pending_must_be_resolved') {
      return '同期待ちの記録があります。先に同じ内容を再送してください。入力は残しています。';
    }
    if (error is StateError && error.message == 'profile_required') {
      return '先にペットのプロフィールを保存してください。';
    }
    return '保存を確認できませんでした。入力を残しています。同期待ちの内容は同じ内容で再送できます。';
  }
}
