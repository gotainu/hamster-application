import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationTokenRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  NotificationTokenRepo({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _tokensCol() {
    final uid = _uid;
    if (uid == null) return null;

    return _db.collection('users').doc(uid).collection('notification_tokens');
  }

  DocumentReference<Map<String, dynamic>>? _tokenDoc(String token) {
    final col = _tokensCol();
    if (col == null) return null;
    return col.doc(token);
  }

  Future<void> saveToken({
    required String token,
    required String platform,
  }) async {
    final doc = _tokenDoc(token);
    if (doc == null) return;

    final now = FieldValue.serverTimestamp();

    await doc.set(
      {
        'token': token,
        'platform': platform,
        'enabled': true,
        'updatedAt': now,
        'createdAt': now,
        'invalidatedAt': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> disableToken(String token) async {
    final doc = _tokenDoc(token);
    if (doc == null) return;

    final now = FieldValue.serverTimestamp();

    await doc.set(
      {
        'enabled': false,
        'updatedAt': now,
        'invalidatedAt': now,
      },
      SetOptions(merge: true),
    );
  }
}
