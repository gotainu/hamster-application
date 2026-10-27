import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/ai_text_consent_gate.dart';
import 'package:hamster_project/services/ai_text_consent_store.dart';

class _Store extends AiTextConsentStore {
  bool accepted = false;
  int generation = 0;
  int writes = 0;
  Future<bool> Function()? read;
  Future<void> Function()? write;

  @override
  int generationFor(String uid) => generation;

  @override
  Future<bool> hasAccepted(String uid) async => read?.call() ?? accepted;

  @override
  Future<void> accept(String uid, {int? expectedGeneration}) async {
    writes++;
    if (expectedGeneration != generation) throw const AiTextConsentChanged();
    await write?.call();
    if (expectedGeneration != generation) throw const AiTextConsentChanged();
    accepted = true;
  }
}

void main() {
  test('a current record authorizes without a new prompt', () async {
    final store = _Store()..accepted = true;
    final gate = AiTextConsentGate(store: store);
    expect(
      await gate.ensureConsent(
        ownerUid: 'A',
        isRequestOwner: () => true,
        requestConsent: () => throw StateError('must not prompt'),
      ),
      isTrue,
    );
    expect(store.writes, 0);
  });

  test(
    'decline creates no permission and a later explicit grant is possible',
    () async {
      final store = _Store();
      final gate = AiTextConsentGate(store: store);
      expect(
        await gate.ensureConsent(
          ownerUid: 'A',
          isRequestOwner: () => true,
          requestConsent: () async => false,
        ),
        isFalse,
      );
      expect(store.writes, 0);
      expect(
        await gate.ensureConsent(
          ownerUid: 'A',
          isRequestOwner: () => true,
          requestConsent: () async => true,
        ),
        isTrue,
      );
      expect(store.writes, 1);
    },
  );

  test(
    'concurrent invocation is refused even when stored consent exists',
    () async {
      final read = Completer<bool>();
      final store = _Store()..read = () => read.future;
      final gate = AiTextConsentGate(store: store);
      final first = gate.ensureConsent(
        ownerUid: 'A',
        isRequestOwner: () => true,
        requestConsent: () async => true,
      );
      expect(
        await gate.ensureConsent(
          ownerUid: 'A',
          isRequestOwner: () => true,
          requestConsent: () async => true,
        ),
        isFalse,
      );
      read.complete(true);
      expect(await first, isTrue);
    },
  );

  test(
    'owner change during storage read blocks prompting and granting',
    () async {
      final read = Completer<bool>();
      var owner = true;
      var prompts = 0;
      final store = _Store()..read = () => read.future;
      final result = AiTextConsentGate(store: store).ensureConsent(
        ownerUid: 'A',
        isRequestOwner: () => owner,
        requestConsent: () async {
          prompts++;
          return true;
        },
      );
      owner = false;
      read.complete(false);
      expect(await result, isFalse);
      expect(prompts, 0);
      expect(store.writes, 0);
    },
  );

  test(
    'owner change or withdrawal while the dialog is open cannot grant',
    () async {
      for (final withdrawn in [false, true]) {
        final store = _Store();
        var owner = true;
        final result = AiTextConsentGate(store: store).ensureConsent(
          ownerUid: 'A',
          isRequestOwner: () => owner,
          requestConsent: () async {
            if (withdrawn) {
              store.generation++;
            } else {
              owner = false;
            }
            return true;
          },
        );
        expect(await result, isFalse);
        expect(store.writes, 0);
      }
    },
  );

  test(
    'owner change after permission save never authorizes transport',
    () async {
      var owner = true;
      final store = _Store()
        ..write = () async {
          owner = false;
        };
      expect(
        await AiTextConsentGate(store: store).ensureConsent(
          ownerUid: 'A',
          isRequestOwner: () => owner,
          requestConsent: () async => true,
        ),
        isFalse,
      );
    },
  );

  test('storage errors propagate and release the non-reentrant gate', () async {
    final store = _Store()
      ..write = () async => throw const AiTextConsentStorageFailure();
    final gate = AiTextConsentGate(store: store);
    Future<bool> attempt() => gate.ensureConsent(
      ownerUid: 'A',
      isRequestOwner: () => true,
      requestConsent: () async => true,
    );
    await expectLater(attempt(), throwsA(isA<AiTextConsentStorageFailure>()));
    store.write = null;
    expect(await attempt(), isTrue);
  });
}
