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

  // Cloudflare Worker URL — Groq key is hidden on server
  static const String _workerUrl =
      'https://cal-bharat-api.rana-yash9876.workers.dev';

  Future<NutritionResult> analyzeFoodImageBytes({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
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
    final uri = Uri.parse(_workerUrl);

    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'base64Image': base64Image,
        'mimeType': mimeType,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }

    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    return NutritionResult.fromJson(jsonMap);
  }
}