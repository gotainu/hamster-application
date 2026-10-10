import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/chat_request_sanitizer.dart';

void main() {
  test('keeps the newest twelve valid messages in their original order', () {
    final history = [
      for (var index = 0; index < 14; index++)
        {'role': index.isEven ? 'user' : 'assistant', 'content': '$index'},
    ];

    final result = sanitizeChatRequestHistory(history);

    expect(result, hasLength(12));
    expect(result.first['content'], '2');
    expect(result.last['content'], '13');
  });

  test('clips each message to 1200 Unicode characters without splitting emoji',
      () {
    final result = sanitizeChatRequestHistory([
      {'role': 'assistant', 'content': '${'あ' * 1199}🙂x'},
    ]);

    expect(result.single['content']!.runes.length, 1200);
    expect(result.single['content'], endsWith('🙂'));
  });

  test('drops roles not accepted by the RAG API', () {
    final result = sanitizeChatRequestHistory([
      {'role': 'system', 'content': 'not sent'},
      {'role': 'user', 'content': 'sent'},
    ]);

    expect(result, [
      {'role': 'user', 'content': 'sent'},
    ]);
  });
}
