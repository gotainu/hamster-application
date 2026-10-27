import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/pending_chat_request_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  PendingChatRequest pending(String uid, String id, {String query = '相談'}) =>
      PendingChatRequest(
        ownerUid: uid,
        requestId: id,
        query: query,
        body: jsonEncode({
          'query': query,
          'history': [
            {'role': 'user', 'content': '前の質問'},
            {'role': 'assistant', 'content': '前の回答'},
            {'role': 'user', 'content': query},
          ],
          'request_id': id
        }),
      );

  test(
      'a recreated store restores exact bytes and owner without reconstruction',
      () async {
    final original = pending('account-A', 'chat_pending_request_123');
    await PendingChatRequestStore().write(original);
    final restored = await PendingChatRequestStore().read('account-A');
    expect(restored!.body, original.body);
    expect(restored.ownerUid, 'account-A');
    expect(restored.requestId, original.requestId);
    expect(await PendingChatRequestStore().read('account-B'), isNull);
  });

  test('owner mismatch or altered query and body fail closed', () {
    final original = pending('account-A', 'chat_pending_request_123');
    expect(() => PendingChatRequest.decode(original.encode(), 'account-B'),
        throwsA(isA<PendingChatStorageFailure>()));
    final changed = jsonDecode(original.encode()) as Map<String, dynamic>;
    changed['query'] = '別の質問';
    expect(() => PendingChatRequest.decode(jsonEncode(changed), 'account-A'),
        throwsA(isA<PendingChatStorageFailure>()));
  });

  test('concurrent stale clear cannot remove a newer pending request',
      () async {
    final store = PendingChatRequestStore();
    final old = pending('account-A', 'chat_old_pending_123');
    final newer = pending('account-A', 'chat_new_pending_456');
    await store.write(old);
    final replacing = store.write(newer);
    final staleClear = store.clear('account-A', old.requestId);
    await Future.wait([replacing, staleClear]);
    expect((await store.read('account-A'))!.body, newer.body);
  });

  test('clearing one owner and request preserves other account pending state',
      () async {
    final store = PendingChatRequestStore();
    final a = pending('account-A', 'chat_account_A_123');
    final b = pending('account-B', 'chat_account_B_456');
    await store.write(a);
    await store.write(b);
    await store.clear(a.ownerUid, a.requestId);
    expect(await store.read(a.ownerUid), isNull);
    expect((await store.read(b.ownerUid))!.body, b.body);
  });

  test('corrupt secure record raises only the fixed safe storage failure',
      () async {
    await const FlutterSecureStorage().write(
        key: 'ai_chat_pending_request_v1_account-A',
        value: 'private malformed data');
    try {
      await PendingChatRequestStore().read('account-A');
      fail('must reject malformed record');
    } catch (error) {
      expect(error, isA<PendingChatStorageFailure>());
      expect(error.toString(), isNot(contains('private')));
    }
  });
}
