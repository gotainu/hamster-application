import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/ai_text_consent_store.dart';

class _Storage extends FlutterSecureStorage {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  Completer<void>? writeStarted;
  Completer<void>? releaseWrite;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failRead) throw StateError('private platform details');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrite) throw StateError('private platform details');
    writeStarted?.complete();
    await releaseWrite?.future;
    values[key] = value!;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failDelete) throw StateError('private platform details');
    values.remove(key);
  }
}

void main() {
  test(
    'permission survives store recreation and remains account scoped',
    () async {
      final storage = _Storage();
      final time = DateTime.utc(2026, 10, 25, 10);
      await AiTextConsentStore(
        storage: storage,
        now: () => time,
      ).accept('persist-A');
      final restarted = AiTextConsentStore(storage: storage);
      expect(await restarted.hasAccepted('persist-A'), isTrue);
      expect(await restarted.hasAccepted('persist-B'), isFalse);
      final record = jsonDecode(storage.values.values.single) as Map;
      expect(record['acceptedAtDeviceUtc'], time.toIso8601String());
      expect(record['providers'], ['openai', 'pinecone']);
      expect(record['purposes'], ['answer_generation', 'knowledge_search']);
      expect(record.keys, isNot(contains('query')));
      expect(record.keys, isNot(contains('token')));
    },
  );

  test(
    'old disclosure or another owner cannot authorize the current account',
    () async {
      final storage = _Storage();
      final store = AiTextConsentStore(storage: storage);
      await store.accept('version-A');
      final key = storage.values.keys.single;
      final record = jsonDecode(storage.values[key]!) as Map<String, dynamic>;
      record['disclosureVersion'] = 'older-disclosure';
      storage.values[key] = jsonEncode(record);
      expect(await store.hasAccepted('version-A'), isFalse);
      record['disclosureVersion'] = AiTextConsentStore.disclosureVersion;
      record['ownerUid'] = 'version-B';
      storage.values[key] = jsonEncode(record);
      expect(await store.hasAccepted('version-A'), isFalse);
    },
  );

  test(
    'withdrawal deletes only this permission and permits a later fresh grant',
    () async {
      final storage = _Storage();
      final store = AiTextConsentStore(storage: storage);
      storage.values['unrelated-secret-key'] = 'unrelated value';
      await store.accept('revoke-A');
      await store.accept('revoke-B');
      await store.revoke('revoke-A');
      expect(await store.hasAccepted('revoke-A'), isFalse);
      expect(await store.hasAccepted('revoke-B'), isTrue);
      expect(storage.values['unrelated-secret-key'], 'unrelated value');
      await store.accept('revoke-A');
      expect(await store.hasAccepted('revoke-A'), isTrue);
    },
  );

  test(
    'withdrawal during a write invalidates the grant and removes its bytes',
    () async {
      final storage = _Storage()
        ..writeStarted = Completer<void>()
        ..releaseWrite = Completer<void>();
      final store = AiTextConsentStore(storage: storage);
      final accepting = store.accept('race-A');
      final rejection = expectLater(
        accepting,
        throwsA(isA<AiTextConsentChanged>()),
      );
      await storage.writeStarted!.future;
      final withdrawing = AiTextConsentStore(storage: storage).revoke('race-A');
      storage.releaseWrite!.complete();
      await rejection;
      await withdrawing;
      expect(await store.hasAccepted('race-A'), isFalse);
      expect(storage.values, isEmpty);
    },
  );

  test(
    'read and malformed-record errors expose only a fixed storage failure',
    () async {
      final storage = _Storage();
      final store = AiTextConsentStore(storage: storage);
      storage.values['ai_text_processing_consent_v1_bad-A'] =
          'private malformed';
      await expectLater(
        store.hasAccepted('bad-A'),
        throwsA(isA<AiTextConsentStorageFailure>()),
      );
      storage.failRead = true;
      try {
        await store.hasAccepted('read-A');
        fail('read failure must not authorize');
      } catch (error) {
        expect(error, isA<AiTextConsentStorageFailure>());
        expect(error.toString(), isNot(contains('private')));
      }
    },
  );

  test(
    'failed writes never grant and failed withdrawal stays blocked in process',
    () async {
      final storage = _Storage()..failWrite = true;
      final store = AiTextConsentStore(storage: storage);
      await expectLater(
        store.accept('failure-A'),
        throwsA(isA<AiTextConsentStorageFailure>()),
      );
      expect(await store.hasAccepted('failure-A'), isFalse);
      storage.failWrite = false;
      await store.accept('failure-A');
      storage.failDelete = true;
      await expectLater(
        store.revoke('failure-A'),
        throwsA(isA<AiTextConsentStorageFailure>()),
      );
      expect(await store.hasAccepted('failure-A'), isFalse);
    },
  );
}
