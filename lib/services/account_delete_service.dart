import 'package:cloud_functions/cloud_functions.dart';

class AccountDeleteService {
  AccountDeleteService({
    FirebaseFunctions? functions,
  }) : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> deleteMyAccountAndData({
    required String confirmText,
    bool deleteAuthUser = true,
  }) async {
    final callable = _functions.httpsCallable('deleteMyAccountAndData');

    final result = await callable.call<Map<String, dynamic>>({
      'confirmText': confirmText,
      'deleteAuthUser': deleteAuthUser,
    });

    return Map<String, dynamic>.from(result.data);
  }
}
