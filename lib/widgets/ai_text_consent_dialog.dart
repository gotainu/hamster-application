import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final aiTextConsentPrivacyUri = Uri.parse(
  'https://hamster-breeding-app.web.app/privacy/',
);

Future<bool> showAiTextConsentDialog(
  BuildContext context, {
  Future<bool> Function(Uri)? openPrivacyPolicy,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AiTextConsentDialog(openPrivacyPolicy: openPrivacyPolicy),
    ) ??
    false;

class AiTextConsentDialog extends StatefulWidget {
  const AiTextConsentDialog({super.key, this.openPrivacyPolicy});

  final Future<bool> Function(Uri)? openPrivacyPolicy;

  @override
  State<AiTextConsentDialog> createState() => _AiTextConsentDialogState();
}

class _AiTextConsentDialogState extends State<AiTextConsentDialog> {
  bool _openingPrivacy = false;
  bool _privacyOpenFailed = false;

  Future<void> _openPrivacy() async {
    if (_openingPrivacy) return;
    setState(() {
      _openingPrivacy = true;
      _privacyOpenFailed = false;
    });
    var opened = false;
    try {
      opened =
          await (widget.openPrivacyPolicy?.call(aiTextConsentPrivacyUri) ??
              launchUrl(
                aiTextConsentPrivacyUri,
                mode: LaunchMode.externalApplication,
              ));
    } catch (_) {
      opened = false;
    } finally {
      if (mounted) {
        setState(() {
          _openingPrivacy = false;
          _privacyOpenFailed = !opened;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('AI相談の情報送信について'),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '回答を作成するため、相談文、直近の会話と、登録済みのペット情報、'
          '飼育環境・記録・センサー評価など、回答に関連する飼育情報を、'
          '運営者のサーバーを経由してOpenAIへ送信します。\n\n'
          '飼育知識の検索では、質問に基づく検索用の数値データ（ベクトル）をPineconeへ送信します。\n\n'
          '同意は設定の「データとプライバシー」から取り消せます。'
          '同意しない場合は送信しません。',
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _openingPrivacy ? null : _openPrivacy,
          child: const Text('プライバシーポリシーを確認する'),
        ),
        if (_privacyOpenFailed) const Text('ページを開けませんでした。同意せずに戻ることもできます。'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('送信しない'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('同意して送信'),
      ),
    ],
  );
}
