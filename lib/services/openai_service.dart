import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String apiKey;

  OpenAIService({required this.apiKey});

  /// AI にメッセージを送信し、返答を取得する
  Future<String> sendMessage(String message) async {
    if (apiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY is not set.');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final requestBody = jsonEncode({
      "model": "gpt-3.5-turbo",
      "messages": [
        {"role": "system", "content": "あなたはハムスター飼育の専門家です。"},
        {"role": "user", "content": message},
      ],
      "temperature": 0.7,
      "max_tokens": 512,
    });

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final response = await http.post(url, headers: headers, body: requestBody);
    final rawBody = utf8.decode(response.bodyBytes);
    // デバッグ出力（必要に応じて）
    // debugPrint('Raw response: $rawBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(rawBody);
      final answer = data['choices'][0]['message']['content'] as String;
      return answer;
    } else {
      throw Exception('エラーが発生しました: ${response.statusCode}\n$rawBody');
    }
  }
}
