/// Thin, data-layer-only exception types that `safeCall` maps to their
/// corresponding domain `Failure`. Kept separate from `Failure` itself so
/// data sources can `throw` synchronously without importing the `Result`
/// type — these mirror the error scenarios called out in the spec (seat
/// unavailable, payment failure, AI timeout, invalid booking).
class SeatUnavailableException implements Exception {
  const SeatUnavailableException([this.message = 'That seat is no longer available.']);
  final String message;
}

class PaymentDeclinedException implements Exception {
  const PaymentDeclinedException([this.message = 'Payment could not be processed.']);
  final String message;
}

class AiTimeoutException implements Exception {
  const AiTimeoutException([this.message = 'The assistant took too long to respond.']);
  final String message;
}

class InvalidBookingException implements Exception {
  const InvalidBookingException([this.message = 'We could not find that booking.']);
  final String message;
}
