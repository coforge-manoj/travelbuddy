/// Base class for all domain-level failures. Kept deliberately small and
/// free of data-layer dependencies so it can be used from domain code.
abstract class Failure {
  const Failure(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'Failure(code: $code, message: $message)';
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'No internet connection.'])
      : super(message, code: 'network_error');
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code = 'server_error'});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([String message = 'The request timed out.'])
      : super(message, code: 'timeout');
}

class SeatUnavailableFailure extends Failure {
  const SeatUnavailableFailure([String message = 'That seat is no longer available.'])
      : super(message, code: 'seat_unavailable');
}

class InvalidBookingFailure extends Failure {
  const InvalidBookingFailure([String message = 'We could not find that booking.'])
      : super(message, code: 'invalid_booking');
}

class PaymentFailure extends Failure {
  const PaymentFailure([String message = 'Payment could not be processed.'])
      : super(message, code: 'payment_failed');
}

class AiTimeoutFailure extends Failure {
  const AiTimeoutFailure([String message = 'The assistant took too long to respond.'])
      : super(message, code: 'ai_timeout');
}

class VoiceRecognitionFailure extends Failure {
  const VoiceRecognitionFailure([String message = "Sorry, I didn't catch that."])
      : super(message, code: 'voice_recognition_failed');
}

class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'Something went wrong.'])
      : super(message, code: 'unknown');
}
