import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/personality_report_view_service.dart';

void main() {
  test(
      'first view patch adds only missing A3 markers and preserves existing timestamps',
      () {
    final changes = personalityFirstViewPatch({
      'firstAiConsultationCompleted': true,
      'monitoringIntroCtaPending': false
    });
    expect(changes.keys.toSet(), {
      'firstPersonalizedAnalysisViewedAt',
      'firstPersonalityReportViewedAt'
    });
    final second = personalityFirstViewPatch({
      'firstPersonalizedAnalysisViewedAt': 'old',
      'firstPersonalityReportViewedAt': 'old'
    });
    expect(second, isEmpty);
    final firstAlreadySeen =
        personalityFirstViewPatch({'firstPersonalizedAnalysisViewedAt': 'old'});
    expect(firstAlreadySeen.keys, ['firstPersonalityReportViewedAt']);
  });
  test('actual views log only metadata and first view is counted once',
      () async {
    bool seen = false;
    final events = <Map<String, Object>>[];
    final service = PersonalityReportViewService(
      currentUid: () => 'owner',
      markFirstView: (uid) async {
        final first = !seen;
        seen = true;
        return first;
      },
      logView: (metadata) async => events.add(metadata),
    );
    await service.recordView(
        ownerUid: 'owner',
        reportId: 'personality_v1_body',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'display1');
    await service.recordView(
        ownerUid: 'owner',
        reportId: 'personality_v1_body',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'display2');
    expect(events.map((e) => e['is_first_view']), [1, 0]);
    expect(events.first.keys.toSet(), {
      'report_id',
      'pet_id',
      'analysis_revision',
      'presentation_id',
      'auto_presented',
      'report_kind',
      'is_first_view'
    });
  });
  test('account switch during marker write cannot log a previous account view',
      () async {
    String uid = 'a';
    final pending = Completer<bool>();
    final events = <Map<String, Object>>[];
    final service = PersonalityReportViewService(
        currentUid: () => uid,
        markFirstView: (_) => pending.future,
        logView: (e) async => events.add(e));
    final work = service.recordView(
        ownerUid: 'a',
        reportId: 'personality_v1_body',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'display');
    uid = 'b';
    pending.complete(true);
    await work;
    expect(events, isEmpty);
  });
  test(
      'logged out, wrong owner and failed marker never produce a false first view',
      () async {
    int writes = 0;
    int events = 0;
    final loggedOut = PersonalityReportViewService(
        currentUid: () => null,
        markFirstView: (_) async {
          writes++;
          return true;
        },
        logView: (_) async {
          events++;
        });
    await loggedOut.recordView(
        ownerUid: 'a',
        reportId: 'r',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'p');
    final wrongOwner = PersonalityReportViewService(
        currentUid: () => 'b',
        markFirstView: (_) async {
          writes++;
          return true;
        },
        logView: (_) async {
          events++;
        });
    await wrongOwner.recordView(
        ownerUid: 'a',
        reportId: 'r',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'p');
    final unavailable = PersonalityReportViewService(
        currentUid: () => 'a',
        markFirstView: (_) async => throw StateError('offline'),
        logView: (_) async {
          events++;
        });
    await unavailable.recordView(
        ownerUid: 'a',
        reportId: 'r',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'p');
    expect(writes, 0);
    expect(events, 0);
  });
  test(
      'report-level actual views retain each identity and never replace another view',
      () async {
    final viewed = <String>{};
    final events = <Map<String, Object>>[];
    final service = PersonalityReportViewService(
        currentUid: () => 'owner',
        markReportViewed: (uid, id) async {
          viewed.add(id);
        },
        markFirstView: (_) async => false,
        logView: (m) async => events.add(m));
    await service.recordView(
        ownerUid: 'owner',
        reportId: 'daily_2026-10-10',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'a');
    await service.recordView(
        ownerUid: 'owner',
        reportId: 'personality_v1_body',
        petId: 'main_pet',
        schemaVersion: 1,
        presentationId: 'b');
    expect(viewed, {'daily_2026-10-10', 'personality_v1_body'});
    expect(
        events.every((e) =>
            e['report_kind'] == 'personality' && e['auto_presented'] == 0),
        isTrue);
  });
  test(
      'legacy first-view patch preserves earliest A3 without personality marker',
      () {
    expect(personalityFirstViewPatch({}, personality: false).keys,
        ['firstPersonalizedAnalysisViewedAt']);
    expect(
        personalityFirstViewPatch({'firstPersonalizedAnalysisViewedAt': 'old'},
            personality: false),
        isEmpty);
  });
}
