import 'ai_text_consent_store.dart';

/// One user action may authorize at most one send attempt through this gate.
class AiTextConsentGate {
  AiTextConsentGate({AiTextConsentStore? store})
    : _store = store ?? AiTextConsentStore();

  final AiTextConsentStore _store;
  bool _isChecking = false;

  Future<bool> ensureConsent({
    required String ownerUid,
    required bool Function() isRequestOwner,
    required Future<bool> Function() requestConsent,
  }) async {
    if (_isChecking || ownerUid.trim().isEmpty || !isRequestOwner()) {
      return false;
    }
    _isChecking = true;
    final generation = _store.generationFor(ownerUid);
    bool isCurrent() =>
        isRequestOwner() && _store.generationFor(ownerUid) == generation;
    try {
      final accepted = await _store.hasAccepted(ownerUid);
      if (!isCurrent()) return false;
      if (accepted) return true;

      final granted = await requestConsent();
      if (!isCurrent() || !granted) return false;

      await _store.accept(ownerUid, expectedGeneration: generation);
      if (!isCurrent()) return false;
      return true;
    } on AiTextConsentChanged {
      return false;
    } finally {
      _isChecking = false;
    }
  }
}
