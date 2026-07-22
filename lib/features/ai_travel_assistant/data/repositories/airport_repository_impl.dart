import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/airport_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/airport_repository.dart';

class AirportRepositoryImpl implements AirportRepository {
  const AirportRepositoryImpl(this._remote);
  final AirportRemoteDataSource _remote;

  @override
  Future<Result<AirportInfo>> getAirportDetails({
    required String flightNumber,
    required String airportCode,
  }) async {
    final result = await safeCall(
      () => _remote.getAirportDetails(flightNumber: flightNumber, airportCode: airportCode),
    );
    return result.map((model) => model.toEntity());
  }
}
