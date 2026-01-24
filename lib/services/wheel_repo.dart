import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WheelRepo {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  WheelRepo({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// breeding_environments/main_env の wheelDiameter を読む（cm想定）
  Future<double?> fetchWheelDiameter() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('breeding_environments')
        .doc('main_env')
        .get();

    final data = doc.data();
    if (data == null) return null;

    final v = data['wheelDiameter'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);

    return null;
  }
}
