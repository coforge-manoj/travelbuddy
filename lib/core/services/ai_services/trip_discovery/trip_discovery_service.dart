  // import 'dart:convert';
  //
  // import 'package:ai_travel_assistant/core/services/ai_services/ai_json_parser.dart';
  // import 'package:ai_travel_assistant/core/services/ai_services/trip_discovery/trip_discovery_promt.dart';
  // import 'package:flutter_dotenv/flutter_dotenv.dart';
  // import 'package:http/http.dart' as http;
  //
  // import '../../../../features/ai_travel_assistant/data/models/trip_discovery/trip_discovery_result_model.dart';
  //
  // class TripDiscoveryService {
  //   TripDiscoveryService._();
  //
  //   static final TripDiscoveryService instance =
  //   TripDiscoveryService._();
  //
  //   final String _apiUrl = dotenv.env['API_URL'] ?? '';
  //   final String _apiKey = dotenv.env['API_KEY'] ?? '';
  //   final String _model =
  //       dotenv.env['MODEL_NAME'] ?? 'gemini-2.5-flash';
  //
  //   Future<TripDiscoveryResult> discover({
  //     required String userMessage,
  //     Map<String, dynamic>? context,
  //   }) async {
  //     try {
  //       final messages = <Map<String, String>>[
  //         {
  //           "role": "system",
  //           "content": TripDiscoveryPrompt.systemPrompt,
  //         },
  //       ];
  //
  //       if (context != null && context.isNotEmpty) {
  //         messages.add({
  //           "role": "system",
  //           "content": "Current Context:\n${jsonEncode(context)}",
  //         });
  //       }
  //
  //       messages.add({
  //         "role": "user",
  //         "content": userMessage,
  //       });
  //
  //       final response = await http.post(
  //         Uri.parse(_apiUrl),
  //         headers: {
  //           "Content-Type": "application/json",
  //           "x-api-key": _apiKey,
  //         },
  //         body: jsonEncode({
  //           "model": _model,
  //           "temperature": 0.3,
  //           "max_tokens": 8192,
  //           "messages": messages,
  //         }),
  //       );
  //
  //       if (response.statusCode != 200) {
  //         throw Exception(
  //           "API Error (${response.statusCode})\n${response.body}",
  //         );
  //       }
  //
  //       final responseJson =
  //       jsonDecode(response.body) as Map<String, dynamic>;
  //
  //       final content =
  //       responseJson["choices"][0]["message"]["content"]
  //           .toString();
  //
  //       print("============== RAW AI RESPONSE ==============");
  //       print(content);
  //       print("=============================================");
  //
  //       final json = AiJsonParser.parseObject(content);
  //
  //       return TripDiscoveryResult.fromJson(json);
  //     } catch (e, stackTrace) {
  //       print("========== Trip Discovery Error ==========");
  //       print(e);
  //       print(stackTrace);
  //
  //       return TripDiscoveryResult.error(
  //         message: e.toString(),
  //       );
  //     }
  //   }
  // }