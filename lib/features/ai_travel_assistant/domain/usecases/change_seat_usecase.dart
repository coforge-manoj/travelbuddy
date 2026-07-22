import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/seat_repository.dart';

class ChangeSeatUseCase {
  const ChangeSeatUseCase(this._seatRepository);
  final SeatRepository _seatRepository;

  Future<Result<Seat>> call({
    required String pnr,
    required String flightNumber,
    required String seatNumber,
  }) {
    return _seatRepository.changeSeat(
      pnr: pnr,
      flightNumber: flightNumber,
      seatNumber: seatNumber,
    );
  }
}
