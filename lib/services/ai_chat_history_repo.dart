import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;

class AiChatAnswerFeedback {
  final String value;
  final String? reason;
  final DateTime? updatedAt;

  const AiChatAnswerFeedback({
    required this.value,
    this.reason,
    this.updatedAt,
  });

  bool get isHelpful => value == 'helpful';
  bool get isNotHelpful => value == 'not_helpful';

  factory AiChatAnswerFeedback.fromJson(Json json) {
    final updatedAtRaw = json['updatedAt'];
    return AiChatAnswerFeedback(
      value: json['value'] as String? ?? '',
      reason: json['reason'] as String?,
      updatedAt:
          updatedAtRaw is Timestamp ? updatedAtRaw.toDate().toLocal() : null,
    );
  }
}

class AiChatHistoryMessage {
  final String id;
  final String role; // user / assistant
  final String content;
  final String? originalQuery;

  /// Server idempotency key for an interrupted user request.
  final String? requestId;
  final List<Json> chunks;
  final Json ragMetadata;
  final AiChatAnswerFeedback? feedback;
  final DateTime? createdAt;

  const AiChatHistoryMessage({
    required this.id,
    required this.role,
    required this.content,
    this.originalQuery,
    this.requestId,
    this.chunks = const [],
    this.ragMetadata = const {},
    this.feedback,
    this.createdAt,
  });

  bool get isUser => role == 'user';

  factory AiChatHistoryMessage.fromDoc(
    QueryDocumentSnapshot<Json> doc,
  ) {
    final data = doc.data();

    final createdAtRaw = data['createdAt'];
    final createdAt =
        createdAtRaw is Timestamp ? createdAtRaw.toDate().toLocal() : null;

    final rawChunks = data['chunks'];
    final chunks = rawChunks is List
        ? rawChunks
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Json>[];

    final rawRagMetadata = data['ragMetadata'];
    final ragMetadata = rawRagMetadata is Map
        ? Map<String, dynamic>.from(rawRagMetadata)
        : const <String, dynamic>{};

    final rawFeedback = data['feedback'];
    final feedback = rawFeedback is Map
        ? AiChatAnswerFeedback.fromJson(Map<String, dynamic>.from(rawFeedback))
        : null;

    return AiChatHistoryMessage(
      id: doc.id,
      role: data['role'] as String? ?? 'assistant',
      content: data['content'] as String? ?? '',
      originalQuery: data['originalQuery'] as String?,
      requestId: data['requestId'] as String?,
      chunks: chunks,
      ragMetadata: ragMetadata,
      feedback: feedback,
      createdAt: createdAt,
    );
  }
}

class AiChatThreadSummary {
  final String id;
  final String lastMessage;
  final String lastRole;
  final int messageCount;
  final DateTime? archivedAt;
  final DateTime? updatedAt;

  const AiChatThreadSummary({
    required this.id,
    required this.lastMessage,
    required this.lastRole,
    required this.messageCount,
    this.archivedAt,
    this.updatedAt,
  });

  factory AiChatThreadSummary.fromArchiveDoc(
    QueryDocumentSnapshot<Json> doc,
  ) {
    final data = doc.data();

    DateTime? toDate(dynamic value) {
      return value is Timestamp ? value.toDate().toLocal() : null;
    }

    return AiChatThreadSummary(
      id: doc.id,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastRole: data['lastRole'] as String? ?? '',
      messageCount: data['messageCount'] as int? ?? 0,
      archivedAt: toDate(data['archivedAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  String get title {
    final text = lastMessage.trim();
    if (text.isEmpty) return '過去の相談';

    return text.length <= 22 ? text : '${text.substring(0, 22)}…';
  }
}

class AiChatHistoryRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  AiChatHistoryRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<AiChatThreadSummary>> watchArchivedThreadSummaries({
    int limit = 30,
  }) {
    final uid = _uid;
    if (uid == null) {
      return Stream<List<AiChatThreadSummary>>.value(const []);
    }

    return _db
        .collection('users')
        .doc(uid)
        .collection('ai_chat_thread_archives')
        .orderBy('archivedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      // 過去の相談は監査・品質改善用に Firestore に残す。ユーザーが
      // 「削除」したものだけを一覧から隠し、既存のアーカイブ（visibility
      // フィールドがまだないもの）もそのまま表示する。
      return snap.docs
          .where((doc) => doc.data()['userVisibility'] != 'hidden')
          .map(AiChatThreadSummary.fromArchiveDoc)
          .toList();
    });
  }

  /// Firestore の会話データは消さず、本人の履歴一覧からだけ非表示にする。
  /// `userVisibility` と時刻を残すことで、JSON として削除状態を追跡できる。
  Future<void> hideArchivedThread({
    required String archiveId,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('ai_chat_thread_archives')
        .doc(archiveId)
        .set(
      {
        'userVisibility': 'hidden',
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenReason': 'user_deleted',
      },
      SetOptions(merge: true),
    );
  }

  Future<List<AiChatHistoryMessage>> fetchArchivedMessages({
    required String archiveId,
    int limit = 100,
  }) async {
    final uid = _uid;
    if (uid == null) return const [];

    final qs = await _db
        .collection('users')
        .doc(uid)
        .collection('ai_chat_thread_archives')
        .doc(archiveId)
        .collection('messages')
        .orderBy('createdAt')
        .limit(limit)
        .get();

    return qs.docs.map(AiChatHistoryMessage.fromDoc).toList();
  }

  CollectionReference<Json>? _messagesCol() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('ai_chat_threads')
        .doc('main')
        .collection('messages');
  }

  DocumentReference<Json>? _threadDoc() {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection('users')
        .doc(uid)
        .collection('ai_chat_threads')
        .doc('main');
  }

  Future<List<AiChatHistoryMessage>> fetchRecentMessages({
    int limit = 50,
  }) async {
    final col = _messagesCol();
    if (col == null) return const [];

    final qs =
        await col.orderBy('createdAt', descending: true).limit(limit).get();

    final messages = qs.docs.map(AiChatHistoryMessage.fromDoc).toList();

    return messages.reversed.toList();
  }

  Future<void> addUserMessage({
    required String content,
    required String requestId,
  }) async {
    await _addMessage(
      role: 'user',
      content: content,
      requestId: requestId,
    );
  }

  Future<void> addAssistantMessage({
    required String messageId,
    required String content,
    required String originalQuery,
    List<Json> chunks = const [],
    Json ragMetadata = const {},
  }) async {
    await _addMessage(
      messageId: messageId,
      role: 'assistant',
      content: content,
      originalQuery: originalQuery,
      chunks: chunks,
      ragMetadata: ragMetadata,
    );
  }

  Future<void> _addMessage({
    String? messageId,
    required String role,
    required String content,
    String? originalQuery,
    String? requestId,
    List<Json> chunks = const [],
    Json ragMetadata = const {},
  }) async {
    final col = _messagesCol();
    final threadDoc = _threadDoc();

    if (col == null || threadDoc == null) return;

    final now = FieldValue.serverTimestamp();

    final resolvedMessageId =
        messageId ?? (requestId == null ? null : 'request_$requestId');
    await col.doc(resolvedMessageId).set(
      {
        'role': role,
        'content': content,
        'originalQuery': originalQuery,
        if (requestId != null) 'requestId': requestId,
        'chunks': chunks,
        'ragMetadata': ragMetadata,
        'createdAt': now,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await threadDoc.set({
      'updatedAt': now,
      'lastMessage': content,
      'lastRole': role,
    }, SetOptions(merge: true));
  }

  Future<void> saveAssistantFeedback({
    required String messageId,
    required String rating,
    required String originalQuery,
    required String answer,
    required List<Json> chunks,
    Json ragMetadata = const {},
    String? reason,
    String? archiveId,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final messageRef = archiveId == null
        ? _messagesCol()?.doc(messageId)
        : _db
            .collection('users')
            .doc(uid)
            .collection('ai_chat_thread_archives')
            .doc(archiveId)
            .collection('messages')
            .doc(messageId);
    if (messageRef == null) return;

    final feedbackRef = _db
        .collection('users')
        .doc(uid)
        .collection('ai_answer_feedback')
        .doc(messageId);
    final now = FieldValue.serverTimestamp();
    final feedback = <String, dynamic>{
      'value': rating,
      'reason': reason,
      'updatedAt': now,
    };

    final batch = _db.batch();
    batch.set(
        messageRef,
        {
          'feedback': feedback,
          'updatedAt': now,
        },
        SetOptions(merge: true));
    batch.set(
        feedbackRef,
        {
          'schemaVersion': 1,
          'messageId': messageId,
          'rating': rating,
          'reason': reason,
          'question': originalQuery,
          'answer': answer,
          'ragMetadata': ragMetadata,
          'sources': _feedbackSources(chunks),
          'updatedAt': now,
        },
        SetOptions(merge: true));
    await batch.commit();
  }

  List<Json> _feedbackSources(List<Json> chunks) {
    return chunks.map((chunk) {
      return <String, dynamic>{
        'chunkId': chunk['id'] as String? ?? '',
        'semanticTitle': chunk['semantic_title'] as String? ?? '',
        'sectionName': chunk['section_name'] as String? ?? '',
        'filename': chunk['filename'] as String? ?? '',
        'metaVersion': chunk['meta_version'] as String? ?? '',
      };
    }).toList();
  }

  Future<void> archiveAndClearMainThread() async {
    final col = _messagesCol();
    final threadDoc = _threadDoc();

    if (col == null || threadDoc == null) return;

    final uid = _uid;
    if (uid == null) return;

    final qs = await col.orderBy('createdAt').limit(200).get();

    if (qs.docs.isEmpty) {
      await threadDoc.set({
        'lastMessage': '',
        'lastRole': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'archivedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final archiveDoc = _db
        .collection('users')
        .doc(uid)
        .collection('ai_chat_thread_archives')
        .doc();

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    batch.set(archiveDoc, {
      'sourceThreadId': 'main',
      'messageCount': qs.docs.length,
      'createdAt': now,
      'updatedAt': now,
      'archivedAt': now,
      'lastMessage': qs.docs.last.data()['content'] as String? ?? '',
      'lastRole': qs.docs.last.data()['role'] as String? ?? '',
      'userVisibility': 'visible',
    });

    for (final doc in qs.docs) {
      final data = doc.data();

      final archivedMessageDoc = archiveDoc.collection('messages').doc(doc.id);

      batch.set(archivedMessageDoc, {
        ...data,
        'sourceMessageId': doc.id,
        'archivedAt': now,
      });

      batch.delete(doc.reference);
    }

    batch.set(
        threadDoc,
        {
          'lastMessage': '',
          'lastRole': '',
          'updatedAt': now,
          'archivedAt': now,
        },
        SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> clearMainThread() async {
    final col = _messagesCol();
    if (col == null) return;

    final qs = await col.limit(200).get();

    final batch = _db.batch();
    for (final doc in qs.docs) {
      batch.delete(doc.reference);
      batch.delete(_feedbackDoc(doc.id));
    }

    await batch.commit();
  }

  Future<int> deleteAllHistory({
    int pageSize = 200,
  }) async {
    final uid = _uid;
    final threadDoc = _threadDoc();

    if (uid == null || threadDoc == null) return 0;

    var deletedCount = 0;

    final mainMessagesCol = _messagesCol();
    if (mainMessagesCol != null) {
      deletedCount += await _deleteCollectionByQuery(
        mainMessagesCol.limit(pageSize),
        pageSize: pageSize,
      );
    }

    final archivesCol =
        _db.collection('users').doc(uid).collection('ai_chat_thread_archives');

    final feedbackCol =
        _db.collection('users').doc(uid).collection('ai_answer_feedback');

    while (true) {
      final archiveSnap = await archivesCol.limit(pageSize).get();

      if (archiveSnap.docs.isEmpty) {
        break;
      }

      for (final archiveDoc in archiveSnap.docs) {
        final archiveMessagesCol = archiveDoc.reference.collection('messages');

        deletedCount += await _deleteCollectionByQuery(
          archiveMessagesCol.limit(pageSize),
          pageSize: pageSize,
        );

        await archiveDoc.reference.delete();
        deletedCount += 1;
      }

      if (archiveSnap.docs.length < pageSize) {
        break;
      }
    }

    deletedCount += await _deleteCollectionByQuery(
      feedbackCol.limit(pageSize),
      pageSize: pageSize,
    );

    await threadDoc.set({
      'lastMessage': '',
      'lastRole': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'clearedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return deletedCount;
  }

  Future<int> _deleteCollectionByQuery(
    Query<Json> query, {
    required int pageSize,
  }) async {
    var deletedCount = 0;

    while (true) {
      final snap = await query.get();

      if (snap.docs.isEmpty) {
        break;
      }

      final batch = _db.batch();

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      deletedCount += snap.docs.length;

      if (snap.docs.length < pageSize) {
        break;
      }
    }

    return deletedCount;
  }

  DocumentReference<Json> _feedbackDoc(String messageId) {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Authentication is required to access answer feedback.');
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('ai_answer_feedback')
        .doc(messageId);
  }
}
