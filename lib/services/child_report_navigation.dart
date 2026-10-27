import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/personality_report_screen.dart';
import 'legacy_first_reports_repo.dart';
import 'personality_report_view_service.dart';
import 'personality_reports_repo.dart';

/// One route and one measurement path for latest, history and frozen first.
Future<void> openChildReport(
  BuildContext context, {
  PersonalityReportsSource? repo,
  String? reportId,
  String? expectedOwnerUid,
  PersonalityReportViewService? viewService,
  LegacyFirstReportSource? legacySource,
  bool legacyFirst = false,
  bool autoPresented = false,
  FutureOr<void> Function()? onLegacyViewed,
}) async {
  final views = viewService ?? PersonalityReportViewService.production();
  final owner = expectedOwnerUid ?? views.currentUid();
  final presentation = 'child_report_${DateTime.now().microsecondsSinceEpoch}';
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PersonalityReportScreen(
            repo: repo,
            reportId: reportId,
            expectedOwnerUid: owner,
            legacySource: legacySource,
            legacyFirst: legacyFirst,
            legacyAutoPresented: autoPresented,
            viewService: views,
            onReportViewed: (report) async {
              if (owner == null || views.currentUid() != owner) return;
              await views.recordView(
                  ownerUid: owner,
                  reportId: report.reportId,
                  petId: report.petId,
                  schemaVersion: report.schemaVersion,
                  presentationId: presentation);
            },
            onLegacyReportViewed: () async {
              if (owner == null || views.currentUid() != owner) return;
              await views.recordLegacyView(ownerUid: owner);
              if (views.currentUid() == owner) await onLegacyViewed?.call();
            },
          )));
}
