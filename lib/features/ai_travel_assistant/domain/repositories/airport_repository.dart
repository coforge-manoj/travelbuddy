import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';

abstract interface class AirportRepository {
  /// GET /airport/details
  Future<Result<AirportInfo>> getAirportDetails({
    required String flightNumber,
    required String airportCode,
  });
}
