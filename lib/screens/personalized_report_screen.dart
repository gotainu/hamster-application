import 'dart:async';
import 'package:flutter/material.dart';
import '../services/legacy_first_reports_repo.dart';
import 'personality_report_screen.dart';
export '../services/legacy_first_reports_repo.dart';

/// Compatibility route: the frozen first snapshot uses the shared report screen.
class PersonalizedReportScreen extends StatelessWidget {
  const PersonalizedReportScreen(
      {super.key,
      this.autoPresented = false,
      this.onReportViewed,
      this.source,
      this.logView,
      this.expectedOwnerUid});
  final bool autoPresented;
  final String? expectedOwnerUid;
  final FutureOr<void> Function()? onReportViewed;
  final LegacyFirstReportSource? source;
  final Future<void> Function(String ownerUid, int revision)? logView;
  @override
  Widget build(BuildContext context) => PersonalityReportScreen(
      legacyFirst: true,
      legacySource: source,
      expectedOwnerUid: expectedOwnerUid,
      onLegacyReportViewed: onReportViewed,
      logLegacyView: logView,
      legacyAutoPresented: autoPresented);
}
