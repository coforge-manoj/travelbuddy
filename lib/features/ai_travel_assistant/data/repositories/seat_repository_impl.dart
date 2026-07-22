import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/core/utils/safe_call.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/seat_remote_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/repositories/seat_repository.dart';

class SeatRepositoryImpl implements SeatRepository {
  const SeatRepositoryImpl(this._remote);
  final SeatRemoteDataSource _remote;

  @override
  Future<Result<SeatMap>> getSeatMap(String flightNumber) async {
    final result = await safeCall(() => _remote.getSeatMap(flightNumber));
    return result.map((model) => model.toEntity());
  }

  @override
  Future<Result<Seat>> changeSeat({
    required String pnr,
    required String flightNumber,
    required String seatNumber,
  }) async {
    final result = await safeCall(
      () => _remote.changeSeat(pnr: pnr, flightNumber: flightNumber, seatNumber: seatNumber),
    );
    return result.map((model) => model.toEntity());
  }
}
