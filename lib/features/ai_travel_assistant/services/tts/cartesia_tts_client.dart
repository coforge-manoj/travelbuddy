import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/speech_trace.dart';

/// Speaks to Cartesia's `/tts/bytes` endpoint and returns rendered mp3 bytes.
///
/// Failures (missing key, offline, timeout, non-2xx) return `null` so the
/// caller can fall back to the on-device engine rather than surfacing an
/// error to the passenger.
class CartesiaTtsClient {
  CartesiaTtsClient({
    Dio? dio,
    String? apiKey,
    String? voiceId,
    String? modelId,
    this.timeout = const Duration(seconds: 30),
  })  : _apiKey = apiKey ?? _env('CARTESIA_API_KEY') ?? '',
        voiceId = voiceId ?? _env('CARTESIA_VOICE_ID') ?? defaultVoiceId,
        modelId = modelId ?? _env('CARTESIA_MODEL_ID') ?? defaultModelId,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.cartesia.ai',
                connectTimeout: timeout,
                // Whole-response budget rather than per-chunk: Cartesia streams
                // the body as it generates, and a mid-generation pause must not
                // abort with a partial mp3.
                receiveTimeout: timeout,
                headers: const {
                  'Cartesia-Version': apiVersion,
                  'Content-Type': 'application/json',
                },
              ),
            );

  /// Katie — Cartesia's recommended en-US female voice for agents.
  static const defaultVoiceId = 'f786b574-daa5-4673-aa0c-cbe3e8534c02';

  static const defaultModelId = 'sonic-3.5';
  static const apiVersion = '2026-03-01';

  final Dio _dio;
  final String _apiKey;
  final String voiceId;
  final String modelId;
  final Duration timeout;

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  /// Safe in unit tests where `dotenv.load` was never called.
  static String? _env(String key) {
    try {
      final value = dotenv.env[key];
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  /// Renders [text], or returns `null` if synthesis failed for any reason.
  ///
  /// The bytes endpoint streams the body while audio is generated. We drain
  /// the stream to completion — returning early would write a truncated mp3
  /// that cuts out mid-sentence on playback.
  Future<Uint8List?> synthesize(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (!hasApiKey) {
      SpeechTrace.step('cartesia.skip', detail: 'no CARTESIA_API_KEY');
      return null;
    }

    SpeechTrace.step(
      'cartesia.post',
      detail: 'model=$modelId chars=${trimmed.length}',
    );
    try {
      final response = await _dio.post<ResponseBody>(
        '/tts/bytes',
        data: {
          'model_id': modelId,
          'transcript': trimmed,
          'voice': {'mode': 'id', 'id': voiceId},
          'language': 'en',
          'output_format': {
            'container': 'mp3',
            'sample_rate': 44100,
            'bit_rate': 128000,
          },
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${_apiKey.trim()}'},
          responseType: ResponseType.stream,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      // Headers arrive as soon as generation starts, so this mark isolates
      // connect + auth + queue time from the render itself.
      SpeechTrace.step(
        'cartesia.headers',
        detail: 'status=${response.statusCode}',
      );
      if (response.statusCode != 200) return null;

      final body = response.data;
      if (body == null) return null;

      final builder = BytesBuilder(copy: false);
      var firstChunk = true;
      await for (final chunk in body.stream) {
        if (firstChunk) {
          firstChunk = false;
          SpeechTrace.step('cartesia.first-byte');
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      SpeechTrace.step('cartesia.body.done', detail: 'bytes=${bytes.length}');
      return bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } catch (error) {
      // Any transport / auth / timeout failure is a fallback signal.
      SpeechTrace.step(
        'cartesia.failed',
        detail: error is DioException ? '${error.type}' : '${error.runtimeType}',
      );
      return null;
    }
  }

  void dispose() {
    _dio.close(force: true);
  }
}
