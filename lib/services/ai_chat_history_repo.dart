import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef Json = Map<String, dynamic>;

class AiChatHistoryMessage {
  final String id;
  final String role; // user / assistant
  final String content;
  final String? originalQuery;
  final List<Json> chunks;
  final DateTime? createdAt;

  const AiChatHistoryMessage({
    required this.id,
    required this.role,
    required this.content,
    this.originalQuery,
    this.chunks = const [],
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

    return AiChatHistoryMessage(
      id: doc.id,
      role: data['role'] as String? ?? 'assistant',
      content: data['content'] as String? ?? '',
      originalQuery: data['originalQuery'] as String?,
      chunks: chunks,
      createdAt: createdAt,
    );
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
  }) async {
    await _addMessage(
      role: 'user',
      content: content,
    );
  }

  Future<void> addAssistantMessage({
    required String content,
    required String originalQuery,
    List<Json> chunks = const [],
  }) async {
    await _addMessage(
      role: 'assistant',
      content: content,
      originalQuery: originalQuery,
      chunks: chunks,
    );
  }

  Future<void> _addMessage({
    required String role,
    required String content,
    String? originalQuery,
    List<Json> chunks = const [],
  }) async {
    final col = _messagesCol();
    final threadDoc = _threadDoc();

    if (col == null || threadDoc == null) return;

    final now = FieldValue.serverTimestamp();

    await col.add({
      'role': role,
      'content': content,
      'originalQuery': originalQuery,
      'chunks': chunks,
      'createdAt': now,
      'updatedAt': now,
    });

    await threadDoc.set({
      'updatedAt': now,
      'lastMessage': content,
      'lastRole': role,
    }, SetOptions(merge: true));
  }

  Future<void> clearMainThread() async {
    final col = _messagesCol();
    if (col == null) return;

    final qs = await col.limit(200).get();

    final batch = _db.batch();
    for (final doc in qs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
