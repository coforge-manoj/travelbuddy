
import 'dart:convert';

class AiJsonParser {
  AiJsonParser._();

  static Map<String, dynamic> parseObject(String response) {
    final cleaned = _extractJson(response);

    final decoded = jsonDecode(cleaned);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException(
      "AI response is not a valid JSON object.",
    );
  }

  static List<dynamic> parseArray(String response) {
    final cleaned = _extractJson(response);

    final decoded = jsonDecode(cleaned);

    if (decoded is List) {
      return decoded;
    }

    throw const FormatException(
      "AI response is not a valid JSON array.",
    );
  }

  static String _extractJson(String text) {
    var value = text.trim();

    value = value
        .replaceAll("```json", "")
        .replaceAll("```", "")
        .trim();

    final firstObject = value.indexOf("{");
    final lastObject = value.lastIndexOf("}");

    if (firstObject != -1 &&
        lastObject != -1 &&
        lastObject > firstObject) {
      return value.substring(
        firstObject,
        lastObject + 1,
      );
    }

    final firstArray = value.indexOf("[");
    final lastArray = value.lastIndexOf("]");

    if (firstArray != -1 &&
        lastArray != -1 &&
        lastArray > firstArray) {
      return value.substring(
        firstArray,
        lastArray + 1,
      );
    }

    throw const FormatException(
      "No JSON found in AI response.",
    );
  }
}