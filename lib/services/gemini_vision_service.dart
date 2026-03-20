import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/nutrition_result.dart';

class GeminiVisionService {
  GeminiVisionService({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const String _prompt = '''
You are an Indian food nutrition expert. Identify the dish in this image. Return JSON only, no extra text:
{
  "dish_name": "",
  "portion_size": "",
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0,
  "confidence": 0
}''';

  Future<NutritionResult> analyzeFoodImageBytes({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'Missing GROQ API key. Run the app with --dart-define=GROQ_API_KEY=YOUR_KEY',
      );
    }

    final base64Image = base64Encode(imageBytes);
    return analyzeFoodImageBase64(
      base64Image: base64Image,
      mimeType: mimeType,
    );
  }

  Future<NutritionResult> analyzeFoodImageBase64({
    required String base64Image,
    required String mimeType,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception(
        'Missing GROQ API key. Run the app with --dart-define=GROQ_API_KEY=YOUR_KEY',
      );
    }

    final uri = Uri.parse(
      'https://api.groq.com/openai/v1/chat/completions',
    );

    final dataUrl = 'data:$mimeType;base64,$base64Image';

    final body = {
      'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': _prompt,
            },
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            },
          ],
        }
      ],
      'temperature': 0.2,
    };

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Groq request failed (${res.statusCode}): ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final text = _extractModelText(decoded);
    final jsonMap = _parseJsonOnly(text);
    return NutritionResult.fromJson(jsonMap);
  }

  static String _extractModelText(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('Groq returned no choices.');
    }

    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final content = message?['content'];

    if (content is String && content.trim().isNotEmpty) {
      return content;
    }

    throw Exception('Groq response did not include text output.');
  }

  static Map<String, dynamic> _parseJsonOnly(String text) {
    var t = text.trim();

    if (t.startsWith('```')) {
      t = t.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
      t = t.replaceAll(RegExp(r'```$'), '');
      t = t.trim();
    }

    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw Exception('Groq did not return JSON. Raw output: $text');
    }

    final jsonString = t.substring(start, end + 1);
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Expected a JSON object. Raw output: $text');
    }
    return decoded;
  }
}

