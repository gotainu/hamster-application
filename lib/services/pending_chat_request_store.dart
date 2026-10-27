import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exact replay data belongs only to the signed-in account that created it.
/// It stays in device secure storage; no token or extra Firestore field is saved.
class PendingChatRequest {
  const PendingChatRequest({
    required this.ownerUid,
    required this.requestId,
    required this.query,
    required this.body,
  });

  final String ownerUid;
  final String requestId;
  final String query;
  final String body;

  factory PendingChatRequest.decode(String value, String expectedOwnerUid) {
    final data = jsonDecode(value);
    if (data is! Map ||
        data['version'] != 1 ||
        data['ownerUid'] != expectedOwnerUid ||
        data['requestId'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{12,128}$')
            .hasMatch(data['requestId'] as String) ||
        data['query'] is! String ||
        data['body'] is! String) {
      throw const PendingChatStorageFailure();
    }
    final payload = jsonDecode(data['body'] as String);
    if (payload is! Map ||
        payload['query'] != data['query'] ||
        payload['request_id'] != data['requestId'] ||
        payload['history'] is! List) {
      throw const PendingChatStorageFailure();
    }
    return PendingChatRequest(
      ownerUid: expectedOwnerUid,
      requestId: data['requestId'] as String,
      query: data['query'] as String,
      body: data['body'] as String,
    );
  }

  String encode() => jsonEncode({
        'version': 1,
        'ownerUid': ownerUid,
        'requestId': requestId,
        'query': query,
        'body': body,
      });
}

class PendingChatStorageFailure implements Exception {
  const PendingChatStorageFailure();
  @override
  String toString() => 'Pending chat state is unavailable.';
}

class PendingChatRequestStore {
  PendingChatRequestStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static final _operations = <String, Future<void>>{};

  Future<T> _serial<T>(String uid, Future<T> Function() action) {
    final previous = _operations[uid] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final done =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _operations[uid] = done;
    unawaited(done.then((_) {
      if (identical(_operations[uid], done)) _operations.remove(uid);
    }));
    return result;
  }

  static String _key(String ownerUid) => 'ai_chat_pending_request_v1_$ownerUid';

  Future<PendingChatRequest?> read(String ownerUid) =>
      _serial(ownerUid, () async {
        try {
          final value = await _storage.read(key: _key(ownerUid));
          return value == null
              ? null
              : PendingChatRequest.decode(value, ownerUid);
        } catch (_) {
          throw const PendingChatStorageFailure();
        }
      });

  Future<void> write(PendingChatRequest request) =>
      _serial(request.ownerUid, () async {
        try {
          await _storage.write(
              key: _key(request.ownerUid), value: request.encode());
        } catch (_) {
          throw const PendingChatStorageFailure();
        }
      });

  Future<void> clear(String ownerUid, String requestId) =>
      _serial(ownerUid, () async {
        try {
          // A late response from an older screen must not remove a newer request.
          final value = await _storage.read(key: _key(ownerUid));
          final pending =
              value == null ? null : PendingChatRequest.decode(value, ownerUid);
          if (pending?.requestId == requestId) {
            await _storage.delete(key: _key(ownerUid));
          }
        } catch (_) {
          throw const PendingChatStorageFailure();
        }
      });
}
