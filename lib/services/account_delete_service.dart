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
    bool stopBillingConfirmed = false,
  }) async {
    final callable = _functions.httpsCallable(
      'deleteMyAccountAndData',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'confirmText': confirmText,
      'deleteAuthUser': deleteAuthUser,
      if (stopBillingConfirmed) 'stopBillingConfirmed': true,
    });

    return Map<String, dynamic>.from(result.data);
  }
}
