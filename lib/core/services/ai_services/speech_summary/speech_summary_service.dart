import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:ai_travel_assistant/core/services/ai_services/speech_summary/speech_summary_promt.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_summarizer.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_trace.dart';

/// LLM-backed [SpeechSummarizer] that rewrites an on-screen reply into the
/// line we speak, falling back to [FallbackSpeechSummarizer] whenever the
/// model is slow, unreachable, or returns something we can't trust.
///
/// The call is bounded by [timeout]. That budget used to be 1800ms, which was
/// below this router's own measured latency (1.9–3.3s for a card narration),
/// so every call expired and every line fell back — paying the full wait for
/// wording that was always discarded. It sits above the measured range now.
///
/// This is affordable because the chat bubble is no longer held back for
/// audio: the reply is on screen immediately and only the speech waits. A
/// passenger who wants speech sooner can turn summarization off in the More
/// tab, which takes this round trip out of the path entirely.
class SpeechSummaryService implements SpeechSummarizer {
  SpeechSummaryService({
    http.Client? client,
    this.fallback = const FallbackSpeechSummarizer(),
    this.timeout = const Duration(milliseconds: 3500),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final FallbackSpeechSummarizer fallback;
  final Duration timeout;

  /// Roughly 40 seconds of speech — far more than the prompt allows, so it
  /// only ever catches a model that has run away.
  static const int maxSpokenCharacters = 900;

  // Read on use, not at construction: `dotenv.env` throws when `load()` was
  // never called, and this service is built eagerly by `speechSummarizerProvider`
  // — which the chat screen's provider graph reaches. A host app that embeds
  // the module without a `.env` would otherwise crash on opening chat. With no
  // credentials, `summarize` falls back to the offline summarizer.
  String get _apiUrl => dotenv.isInitialized ? (dotenv.env['API_URL'] ?? '') : '';
  String get _apiKey => dotenv.isInitialized ? (dotenv.env['API_KEY'] ?? '') : '';
  String get _model =>
      (dotenv.isInitialized ? dotenv.env['MODEL_NAME'] : null) ??
          'gemini-2.5-flash';

  @override
  Future<String> summarize(String text) async {
    final source = FallbackSpeechSummarizer.stripForSpeech(text);
    if (source.isEmpty) return '';

    // Short lines are already speakable; a model round-trip would only add
    // latency and risk.
    if (source.length < 80 && !source.contains('\n')) {
      SpeechTrace.step('summarize.skip', detail: 'short line, no LLM call');
      return source;
    }
    if (_apiUrl.isEmpty || _apiKey.isEmpty) {
      SpeechTrace.step('summarize.skip', detail: 'no API_URL/API_KEY');
      return fallback.condense(text);
    }

    SpeechTrace.step(
      'summarize.llm.post',
      detail: 'model=$_model chars=${source.length} budget=${timeout.inMilliseconds}ms',
    );
    try {
      final response = await _client
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _apiKey,
            },
            body: jsonEncode({
              'model': _model,
              // Slightly warmer than a strict rewrite so fillers and phrasing
              // vary across turns instead of repeating the same opener.
              'temperature': 0.55,
              // Headroom over what the prompt asks for: at 200 a three-sentence
              // rewrite could be cut off by the token limit itself, and a
              // completion that stops mid-word is spoken exactly that way.
              'max_tokens': 320,
              'messages': [
                {
                  'role': 'system',
                  'content': SpeechSummaryPrompt.systemPrompt,
                },
                {'role': 'user', 'content': source},
              ],
            }),
          )
          .timeout(timeout);

      SpeechTrace.step(
        'summarize.llm.response',
        detail: 'status=${response.statusCode}',
      );
      if (response.statusCode != 200) return fallback.condense(text);

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) return fallback.condense(text);

      final first = choices.first;
      if (first is! Map) return fallback.condense(text);

      final message = first['message'];
      if (message is! Map) return fallback.condense(text);

      final raw = message['content']?.toString();
      if (raw == null) return fallback.condense(text);

      // Cleaned, not re-condensed. Running the model's answer back through
      // `condense` re-applied the offline sentence/character caps to copy that
      // was already written for the ear — which is how a good two-sentence
      // rewrite ended up truncated mid-clause.
      final candidate = FallbackSpeechSummarizer.stripForSpeech(_unquote(raw));
      if (candidate.isEmpty) return fallback.condense(text);

      // Fact guard: the model may only rephrase what we gave it. If it
      // produced a number that isn't in the source, we don't say it.
      if (_inventsNumbers(candidate, source)) return fallback.condense(text);

      // A backstop for a model that ignores the length rule, not a second
      // opinion on wording: well above anything the prompt asks for, and it
      // ends on a sentence rather than mid-clause.
      if (candidate.length > maxSpokenCharacters) {
        return const FallbackSpeechSummarizer(
          maxSentences: 5,
          maxCharacters: maxSpokenCharacters,
        ).condense(candidate);
      }

      return candidate;
    } catch (error) {
      // A timeout here is the single most likely cause of a slow-to-speak
      // reply, so it is named rather than folded into a silent fallback.
      SpeechTrace.step(
        'summarize.llm.failed',
        detail: '${error.runtimeType} — using offline summary',
      );
      return fallback.condense(text);
    }
  }

  /// Models occasionally wrap the answer in quotes or a stray code fence.
  String _unquote(String text) {
    var cleaned = text.replaceAll('```', '').trim();
    if (cleaned.length > 1 &&
        ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
            (cleaned.startsWith("'") && cleaned.endsWith("'")))) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    return cleaned.trim();
  }

  /// True when [candidate] contains a digit run absent from [source].
  ///
  /// Spelled-out codes are expected — "UA482" may legitimately come back as
  /// "U A 482" — so digits are compared with spacing removed.
  bool _inventsNumbers(String candidate, String source) {
    final sourceDigits = source.replaceAll(RegExp(r'[^0-9]'), '');
    final candidateRuns = RegExp(r'\d+')
        .allMatches(candidate.replaceAll(RegExp(r'(?<=\d)[\s,](?=\d)'), ''))
        .map((match) => match.group(0)!);

    return candidateRuns.any((run) => !sourceDigits.contains(run));
  }
}
