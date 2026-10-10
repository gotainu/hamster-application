const maxChatRequestHistoryMessages = 12;
const maxChatRequestHistoryContentRunes = 1200;
const maxChatRequestQueryRunes = 1500;

List<Map<String, String>> sanitizeChatRequestHistory(
  Iterable<Map<String, String>> history,
) {
  final validMessages = history
      .where((message) =>
          message['role'] == 'user' || message['role'] == 'assistant')
      .toList(growable: false);
  final startIndex = validMessages.length > maxChatRequestHistoryMessages
      ? validMessages.length - maxChatRequestHistoryMessages
      : 0;

  return validMessages.skip(startIndex).map((message) {
    final contentRunes = (message['content'] ?? '')
        .runes
        .take(maxChatRequestHistoryContentRunes);
    return <String, String>{
      'role': message['role']!,
      'content': String.fromCharCodes(contentRunes),
    };
  }).toList(growable: false);
}
