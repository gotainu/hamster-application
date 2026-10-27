import 'package:intl/intl.dart';
import '../models/legacy_first_report.dart';

class LegacyFirstReportViewModel {
  const LegacyFirstReportViewModel(this.snapshot);
  final LegacyFirstReportSnapshot snapshot;
  String? get generatedAtLabel {
    final date = snapshot.generatedAt;
    return date == null
        ? null
        : DateFormat('yyyy/M/d')
            .format(date.toUtc().add(const Duration(hours: 9)));
  }
}
