import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/services/tts/cartesia_tts_client.dart';

/// Stub Dio adapter that returns a canned streamed body for `/tts/bytes`.
class _FakeStreamAdapter implements HttpClientAdapter {
  _FakeStreamAdapter({
    this.statusCode = 200,
    this.body,
    this.chunkDelay = Duration.zero,
  });

  final int statusCode;
  final List<int>? body;
  final Duration chunkDelay;
  RequestOptions? lastOptions;
  Object? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    lastData = options.data;
    final bytes = body ?? const <int>[];

    // Mimic Cartesia's streaming body: several small chunks, not one blob.
    Stream<Uint8List> stream() async* {
      const chunkSize = 2;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        if (chunkDelay > Duration.zero) await Future<void>.delayed(chunkDelay);
        yield Uint8List.fromList(bytes.sublist(i, end));
      }
    }

    return ResponseBody(
      stream(),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['audio/mpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late _FakeStreamAdapter adapter;
  late CartesiaTtsClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.cartesia.ai'));
    adapter = _FakeStreamAdapter(body: [1, 2, 3, 4, 5]);
    dio.httpClientAdapter = adapter;
    client = CartesiaTtsClient(
      dio: dio,
      apiKey: 'sk_car_test',
      voiceId: CartesiaTtsClient.defaultVoiceId,
      modelId: CartesiaTtsClient.defaultModelId,
    );
  });

  tearDown(() {
    client.dispose();
  });

  test('synthesize drains the streamed body into full mp3 bytes', () async {
    final result = await client.synthesize('Gate B12 is boarding.');

    expect(result, Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(adapter.lastOptions?.path, '/tts/bytes');
    expect(adapter.lastOptions?.headers['Authorization'], 'Bearer sk_car_test');
    final data = adapter.lastData as Map<String, dynamic>;
    expect(data['transcript'], 'Gate B12 is boarding.');
    expect(data['model_id'], CartesiaTtsClient.defaultModelId);
    expect(data['voice'], {
      'mode': 'id',
      'id': CartesiaTtsClient.defaultVoiceId,
    });
    expect(data['output_format']['container'], 'mp3');
  });

  test('synthesize returns null when the API key is missing', () async {
    final noKey = CartesiaTtsClient(dio: dio, apiKey: '');
    expect(await noKey.synthesize('Hello'), isNull);
    noKey.dispose();
  });

  test('synthesize returns null on HTTP failure', () async {
    adapter = _FakeStreamAdapter(statusCode: 401, body: [123]);
    dio.httpClientAdapter = adapter;

    expect(await client.synthesize('Hello'), isNull);
  });

  test('synthesize returns null for blank text', () async {
    expect(await client.synthesize('   '), isNull);
  });
}
