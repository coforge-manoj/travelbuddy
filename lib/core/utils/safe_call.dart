import 'package:dio/dio.dart';
import 'package:ai_travel_assistant/core/errors/exceptions.dart';
import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';

/// Wraps a data-source call, mapping thrown exceptions to domain [Failure]s
/// so repositories never let raw exceptions cross into the domain layer.
Future<Result<T>> safeCall<T>(Future<T> Function() action) async {
  try {
    final value = await action();
    return Result.success(value);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const Result.failure(TimeoutFailure());
    }
    if (e.type == DioExceptionType.connectionError) {
      return const Result.failure(NetworkFailure());
    }
    return Result.failure(ServerFailure(e.message ?? 'Server error.'));
  } on SeatUnavailableException catch (e) {
    return Result.failure(SeatUnavailableFailure(e.message));
  } on PaymentDeclinedException catch (e) {
    return Result.failure(PaymentFailure(e.message));
  } on AiTimeoutException catch (e) {
    return Result.failure(AiTimeoutFailure(e.message));
  } on InvalidBookingException catch (e) {
    return Result.failure(InvalidBookingFailure(e.message));
  } catch (e) {
    return Result.failure(UnknownFailure(e.toString()));
  }
}
