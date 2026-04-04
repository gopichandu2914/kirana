import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// NOTE: Class name kept as GeminiService to avoid breaking UI imports, 
/// but it is now powered by **Groq LPU** for 10x faster responses. 🚀
class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY']!;
  static const _model = 'llama-3.3-70b-versatile';
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  /// Helper to call Groq API (OpenAI Compatible)
  static Future<String> _getGroqResponse(String systemPrompt, String userPrompt) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString().trim();
      } else {
        throw Exception('Groq API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('Groq error: $e');
      rethrow;
    }
  }

  /// Parses a voice command and extracts intent, product, quantity, price.
  static Future<Map<String, dynamic>?> parseVoiceCommand(String spokenText) async {
    const systemPrompt = '''
    You are an AI assistant for an Indian shopkeeper. Extract intent, product, and quantity.
    Respond ONLY with valid JSON:
    {
      "intent": "sale" | "add_stock" | "add_product" | "query_inventory",
      "product": "product name in English",
      "quantity": integer or null,
      "price": number or null
    }
    ''';
    
    final userPrompt = 'Extract from: "$spokenText"';

    try {
      final result = await _getGroqResponse(systemPrompt, userPrompt);
      final jsonString = result.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(jsonString);
    } catch (e) {
      print('Voice parsing error: $e');
      return null;
    }
  }

  /// Returns a list of 3 suggestion maps: {emoji, title, detail}
  static Future<List<Map<String, String>>> getSeasonalSuggestionCards(String languageCode) async {
    final currentMonth = DateTime.now().month;
    String season = 'Winter';
    if (currentMonth >= 3 && currentMonth <= 5) season = 'Summer (Grishma)';
    if (currentMonth >= 6 && currentMonth <= 9) season = 'Monsoon / Rainy';
    if (currentMonth == 10 || currentMonth == 11) season = 'Autumn / Festival season';

    final lang = languageCode == 'te' ? 'Telugu' : languageCode == 'hi' ? 'Hindi' : 'English';

    final systemPrompt = '''
    You are a business consultant for a small Indian Kirana shop. 
    Suggest 3 products to stock for $season. Respond ONLY with valid JSON array:
    [
      {"emoji": "🥤", "title": "Title in $lang", "detail": "Reason in $lang"}
    ]
    ''';

    try {
      final result = await _getGroqResponse(systemPrompt, 'Current season: $season. Language: $lang');
      final jsonString = result.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(jsonString) as List;
      return decoded.map<Map<String, String>>((e) => {
        'emoji': e['emoji'] ?? '📦',
        'title': e['title'] ?? '',
        'detail': e['detail'] ?? '',
      }).toList();
    } catch (e) {
      print('Suggestion error: $e');
      return [
        {'emoji': '📶', 'title': 'Connection Error', 'detail': 'Could not load tips. Check Groq API/Internet.'},
      ];
    }
  }

  /// Generates a catchy sales pitch 
  static Future<String> generateProductPitch(String productName, String languageCode) async {
    final lang = languageCode == 'te' ? 'Telugu' : languageCode == 'hi' ? 'Hindi' : 'English';

    final systemPrompt = '''
    Generate a friendly 1-sentence sales pitch (max 20 words) for $productName in $lang. 
    Focus on quality and freshness. Plain text only.
    ''';

    try {
      return await _getGroqResponse(systemPrompt, 'Product: $productName. Language: $lang');
    } catch (e) {
      return 'Best quality product at the right price!';
    }
  }
}
