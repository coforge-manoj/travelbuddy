import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';

abstract interface class SeatRepository {
  /// GET /seatmap
  Future<Result<SeatMap>> getSeatMap(String flightNumber);

  /// POST /seat/change
  Future<Result<Seat>> changeSeat({
    required String pnr,
    required String flightNumber,
    required String seatNumber,
  });
}
