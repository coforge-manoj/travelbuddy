import '../../../../core/services/api_services/api_service.dart';

class FlightServices {
  final ApiService _apiService = ApiService(
    baseUrl:
    'https://flying-rug-probably-deemed.trycloudflare.com',
  );

  Future<dynamic> getFlightResponse(
      String message,
      ) async {
    final response = await _apiService.post(
      '/api/v1/chat',
      headers: {
        'x-member-no': '5QW08HB',
        'x-session-id': 'pm-1785998155539',
        'x-api-key':
        'njv+D1R/BdIz/U0BS7p1aN+6TodQI5hnKVZw3eThx4Y=',
      },
      body: {
        'message': message,
      },
    );

    print(response);
    return response;
  }
}