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
/// The call is bounded by [timeout]. That budget has now been wrong in both
/// directions. At 1800ms it sat below this router's measured latency
/// (1.9–3.3s), so every call expired and every line fell back — paying the
/// full wait for wording that was always discarded. Raised to 3500ms it sat
/// just *at* the latency, which is the same failure with better odds: two
/// consecutive on-device turns timed out at ~3.5s and used the offline
/// summary anyway.
///
/// 6000ms clears the measured range rather than grazing it. The reason to
/// prefer a longer budget over a shorter one is that the wait is no longer the
/// passenger's: `ChatViewModel._renderAhead` starts this call the moment the
/// reply arrives, while the acknowledgement is still being spoken, so a call
/// that finishes inside the acknowledgement costs nothing at all. A budget
/// that expires early converts that free time into a worse-worded line for no
/// saving.
///
/// This is affordable because the chat bubble is no longer held back for
/// audio: the reply is on screen immediately and only the speech waits. A
/// passenger who wants speech sooner can turn summarization off in the More
/// tab, which takes this round trip out of the path entirely.
class SpeechSummaryService implements SpeechSummarizer {
  SpeechSummaryService({
    http.Client? client,
    this.fallback = const FallbackSpeechSummarizer(),
    this.timeout = const Duration(milliseconds: 6000),
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
              // Sized for a *thinking* model, not for the answer.
              //
              // 320 was headroom over the two or three sentences the prompt
              // asks for — ample, if every token were spoken. But
              // `gemini-2.5-flash` reasons before it answers, and on an
              // OpenAI-compatible gateway those reasoning tokens come out of
              // this same budget. The visible answer gets whatever is left: a
              // reply measured on-device came back at 51 characters, roughly a
              // dozen tokens, cut mid-clause.
              //
              // 1024 leaves room for the reasoning pass and a complete answer.
              // It costs nothing when unused — completions are billed on what
              // is generated, not on the ceiling — and the prompt, not this
              // number, is what keeps the reply short.
              'max_tokens': 1024,
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

      // Token accounting, traced because it is the only way to tell a model
      // that answered briefly from one that ran out of budget mid-sentence.
      // A `reasoning_tokens` figure far larger than `completion_tokens` is the
      // thinking model eating the ceiling — see the note on `max_tokens`.
      _traceUsage(decoded['usage']);
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

      // Completeness guard: a rewrite that stops mid-sentence is spoken exactly
      // that way, and a sentence that just stops sounds like the assistant was
      // cut off rather than like it finished.
      //
      // Observed on a device: "I can search flights, book, add extras, pick
      // seats, check you in, upgrade or cancel. What would you like to do?"
      // came back as "Alright, Elena, I can help you search flights, book" —
      // 51 characters, ending on a comma clause. Well under `max_tokens: 320`,
      // so the cap that produced it is the router's, not ours, and cannot be
      // raised from here.
      //
      // `finish_reason` is checked first because it is the router *saying* it
      // truncated; the punctuation test catches the routers that don't report
      // it. The offline summary is complete by construction, which is the one
      // property that matters here.
      final finishReason = first['finish_reason']?.toString();
      if (finishReason == 'length' || _looksTruncated(candidate)) {
        SpeechTrace.step(
          'summarize.truncated',
          detail: 'reason=${finishReason ?? 'no terminator'} '
              'out=${candidate.length} — using offline summary',
        );
        return fallback.condense(text);
      }

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

  /// Reports whatever token counts the router returned.
  ///
  /// Shapes vary between gateways, so nothing here is required: an absent
  /// `usage` block, or one with different key names, simply traces less rather
  /// than throwing on a path whose whole job is to degrade gracefully.
  void _traceUsage(Object? usage) {
    if (usage is! Map) return;
    final completion = usage['completion_tokens'];
    final details = usage['completion_tokens_details'];
    final reasoning =
        details is Map ? details['reasoning_tokens'] : usage['reasoning_tokens'];

    SpeechTrace.step(
      'summarize.llm.usage',
      detail: 'completion=$completion reasoning=${reasoning ?? 'n/a'} '
          'total=${usage['total_tokens']}',
    );
  }

  /// Whether [candidate] reads as a completion that was cut off.
  ///
  /// A finished rewrite ends on a sentence — the prompt asks for one or two of
  /// them and every example ends in `.` or `?`. Anything ending mid-clause is
  /// either a truncation or a model ignoring the format badly enough that the
  /// deterministic summary is the better line to speak.
  ///
  /// A closing quote or bracket counts as terminal: "…what would you like to
  /// do?)" is complete, just punctuated oddly.
  bool _looksTruncated(String candidate) {
    final trimmed = candidate.replaceAll(RegExp(r'''["'”’)\]]+$'''), '').trim();
    if (trimmed.isEmpty) return true;
    return !RegExp(r'[.!?…]$').hasMatch(trimmed);
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
