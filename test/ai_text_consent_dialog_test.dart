import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/widgets/ai_text_consent_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    void Function(bool) onResult, {
    Future<bool> Function(Uri)? policy,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                child: const Text('open'),
                onPressed: () async => onResult(
                  await showAiTextConsentDialog(
                    context,
                    openPrivacyPolicy: policy ?? (_) async => true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('only the affirmative send button grants permission', (
    tester,
  ) async {
    bool? result;
    await open(tester, (value) => result = value);
    expect(find.textContaining('OpenAI'), findsOneWidget);
    expect(find.textContaining('Pinecone'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('同意して送信'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('declining or using system back returns false', (tester) async {
    bool? result;
    await open(tester, (value) => result = value);
    await tester.tap(find.text('送信しない'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    result = null;
    await open(tester, (value) => result = value);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets(
    'policy link uses the public URL and does not count as agreement',
    (tester) async {
      bool? result;
      Uri? opened;
      await open(
        tester,
        (value) => result = value,
        policy: (uri) async {
          opened = uri;
          return false;
        },
      );
      await tester.ensureVisible(find.text('プライバシーポリシーを確認する'));
      await tester.tap(find.text('プライバシーポリシーを確認する'));
      await tester.pumpAndSettle();
      expect(
        opened.toString(),
        'https://hamster-breeding-app.web.app/privacy/',
      );
      expect(result, isNull);
      expect(find.textContaining('ページを開けませんでした'), findsOneWidget);
      await tester.tap(find.text('送信しない'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    },
  );

  testWidgets('small display and large text retain reachable choice buttons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool? result;
    await open(tester, (value) => result = value, textScale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('送信しない'));
    await tester.tap(find.text('送信しない'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
