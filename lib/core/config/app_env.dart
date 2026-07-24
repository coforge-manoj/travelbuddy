import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to values loaded from the local `.env` file (see `.env.example`).
///
/// Keep secrets out of source: the key lives in the git-ignored `.env`, is
/// bundled as an asset, and is read here at runtime. Call [ensureLoaded] once
/// during app startup (before reading any value) so a missing `.env` degrades
/// gracefully instead of crashing.
class AppEnv {
  const AppEnv._();

  static const String _customLlmUrlName = 'CUSTOM_LLM_URL';
  static const String _customLlmApiKeyName = 'CUSTOM_LLM_API_KEY';
  static const String _customLlmModelName = 'CUSTOM_LLM_MODEL';

  /// Loads `.env` if present. Safe to call more than once; never throws — a
  /// missing file just leaves the keys empty, which the UI surfaces as
  /// "add your API key".
  static Future<void> ensureLoaded() async {
    if (dotenv.isInitialized) return;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No .env bundled — leave values empty; callers handle the empty key.
      dotenv.testLoad(fileInput: '');
    }
  }

  /// The custom OpenAI-compatible gateway URL, or an empty string if unset.
  static String get customLlmUrl =>
      dotenv.maybeGet(_customLlmUrlName, fallback: '') ?? '';

  /// The custom gateway API key (sent as `X-API-KEY`), or empty if unset.
  static String get customLlmApiKey =>
      dotenv.maybeGet(_customLlmApiKeyName, fallback: '') ?? '';

  /// The model name to send to the custom gateway. Defaults to
  /// `gemini-2-5-flash` when unset.
  static String get customLlmModel {
    final model = dotenv.maybeGet(_customLlmModelName, fallback: '') ?? '';
    return model.trim().isNotEmpty ? model.trim() : 'gemini-2-5-flash';
  }

  /// True when both the custom gateway URL and key are configured, so the
  /// custom adapter should be used in preference to the direct Gemini API.
  static bool get hasCustomLlm =>
      customLlmUrl.trim().isNotEmpty && customLlmApiKey.trim().isNotEmpty;
}
