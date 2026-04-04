import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  try {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: dotenv.env['TEST_GEMINI_API_KEY']!,
    );
    final content = [Content.text("Hello")];
    final response = await model.generateContent(content);
    print("Success!");
    exit(0);
  } catch (e) {
    print("ExactError: ");
    print(e.toString());
    exit(1);
  }
}
