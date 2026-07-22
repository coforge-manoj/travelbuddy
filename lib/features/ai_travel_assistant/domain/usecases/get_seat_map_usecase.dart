import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/seat_repository.dart';

class GetSeatMapUseCase {
  const GetSeatMapUseCase(this._seatRepository);
  final SeatRepository _seatRepository;

  Future<Result<SeatMap>> call(String flightNumber) {
    return _seatRepository.getSeatMap(flightNumber);
  }
}
