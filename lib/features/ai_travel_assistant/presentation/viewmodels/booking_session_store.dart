import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/booking.dart';

/// Remembers the passenger's most recently confirmed booking for the
/// lifetime of the app process. Unlike [ChatState] — which `ChatViewModel`
/// resets every time the chat screen re-opens (see the `autoDispose` on
/// `chatViewModelProvider`) — this survives across sessions, so a seat,
/// baggage, or status request typed in a *later* session still resolves to
/// the flight the passenger actually booked instead of falling back to demo
/// data.
class BookingSessionStore {
  Booking? confirmedBooking;
}

/// Deliberately not `autoDispose`, so it outlives every chat session.
final bookingSessionStoreProvider = Provider<BookingSessionStore>((ref) {
  return BookingSessionStore();
});
