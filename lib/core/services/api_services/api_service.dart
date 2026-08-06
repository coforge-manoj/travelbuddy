import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({
    required this.baseUrl,
  });

  Future<dynamic> get(
      String endpoint, {
        Map<String, String>? headers,
        Map<String, dynamic>? queryParams,
      }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(
        queryParameters:
        queryParams?.map(
              (key, value) => MapEntry(key, value.toString()),
        ),
      );

      final response = await http.get(
        uri,
        headers: _defaultHeaders(headers),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('GET Error: $e');
    }
  }

  Future<dynamic> post(
      String endpoint, {
        Map<String, String>? headers,
        dynamic body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await http.post(
        uri,
        headers: _defaultHeaders(headers),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('POST Error: $e');
    }
  }

  Map<String, String> _defaultHeaders(
      Map<String, String>? headers,
      ) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw Exception(
      'API Error: $statusCode\n${response.body}',
    );
  }
}