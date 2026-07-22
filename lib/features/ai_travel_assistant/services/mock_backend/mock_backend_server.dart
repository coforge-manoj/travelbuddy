import 'dart:math';

import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/airport_info_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/baggage_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/booking_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/flight_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/models/seat_model.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/intent.dart';

/// A single in-memory "server" shared by every `Mock*RemoteDataSource`, so a
/// demo session behaves consistently — e.g. a seat selected via
/// `changeSeat` shows up as unavailable on the next `getSeatMap` call — and
/// so the error scenarios called out in the spec (no internet, seat taken,
/// payment declined, AI timeout) can be toggled from one place for manual
/// QA or tests.
///
/// This is intentionally simple: a singleton with mutable in-memory maps.
/// It exists purely to make the mock data sources believable until a real
/// backend is wired in behind `useMockBackendProvider`.
class MockBackendServer {
  MockBackendServer._internal();
  static final MockBackendServer instance = MockBackendServer._internal();

  // ---------------------------------------------------------------------
  // Error injection — flip these (e.g. from a debug menu, or in a test's
  // setUp) to exercise the error-handling paths required by the spec.
  // ---------------------------------------------------------------------
  bool simulateNetworkError = false;
  bool simulateTimeout = false;
  bool simulateSeatUnavailable = false;
  bool simulatePaymentFailure = false;
  bool simulateAiTimeout = false;

  void resetErrorInjection() {
    simulateNetworkError = false;
    simulateTimeout = false;
    simulateSeatUnavailable = false;
    simulatePaymentFailure = false;
    simulateAiTimeout = false;
  }

  final _random = Random();

  // ---------------------------------------------------------------------
  // Flights / booking
  // ---------------------------------------------------------------------
  final Map<String, FlightModel> _flights = {};

  FlightModel flight(String flightNumber) {
    return _flights.putIfAbsent(flightNumber, () {
      final now = DateTime.now();
      return FlightModel(
        flightNumber: flightNumber,
        origin: 'DXB',
        destination: 'LHR',
        status: 'delayed',
        scheduledDeparture: now.add(const Duration(hours: 2)).toIso8601String(),
        estimatedDeparture: now.add(const Duration(hours: 2, minutes: 35)).toIso8601String(),
        gate: 'B12',
        terminal: '2',
        checkInCounter: '14-18',
        boardingTime: now.add(const Duration(hours: 1, minutes: 40)).toIso8601String(),
      );
    });
  }

  BookingModel booking(String pnr) {
    return BookingModel(pnr: pnr, passengerName: 'A. Passenger', flight: flight('FZ123'));
  }

  // ---------------------------------------------------------------------
  // Seat map — mutable, so a selection persists for the rest of the session.
  // ---------------------------------------------------------------------
  final Map<String, List<SeatModel>> _seatMaps = {};

  List<SeatModel> _generateSeats() {
    final seats = <SeatModel>[];
    for (var row = 12; row <= 20; row++) {
      for (final column in ['A', 'B', 'C', 'D', 'E', 'F']) {
        final type = column == 'A' || column == 'F'
            ? 'window'
            : column == 'C' || column == 'D'
                ? 'aisle'
                : 'middle';
        final availability = (row + column.codeUnitAt(0)) % 5 == 0 ? 'occupied' : 'available';
        seats.add(
          SeatModel(
            seatNumber: '$row$column',
            row: row,
            column: column,
            type: type,
            availability: availability,
            priceDelta: type == 'window' ? 15 : 0,
            isExitRow: row == 14,
          ),
        );
      }
    }
    return seats;
  }

  SeatMapModel seatMap(String flightNumber) {
    final seats = _seatMaps.putIfAbsent(flightNumber, _generateSeats);
    return SeatMapModel(flightNumber: flightNumber, rows: 9, seats: seats, currency: 'USD');
  }

  /// Returns the updated seat, or `null` if [simulateSeatUnavailable] is set
  /// or the seat has since been taken.
  SeatModel? changeSeat({required String flightNumber, required String seatNumber}) {
    if (simulateSeatUnavailable) return null;
    final seats = _seatMaps.putIfAbsent(flightNumber, _generateSeats);
    final index = seats.indexWhere((s) => s.seatNumber == seatNumber);
    if (index == -1 || seats[index].availability == 'occupied') return null;

    final updated = seats[index].copyWith(availability: 'selected');
    seats[index] = updated;
    return updated;
  }

  // ---------------------------------------------------------------------
  // Baggage
  // ---------------------------------------------------------------------
  static const _baggageOptions = [
    BaggageOptionModel(id: 'bag_5kg', extraWeightKg: 5, price: 25),
    BaggageOptionModel(id: 'bag_10kg', extraWeightKg: 10, price: 45),
    BaggageOptionModel(id: 'bag_20kg', extraWeightKg: 20, price: 80),
  ];

  final List<BaggagePurchaseModel> purchaseHistory = [];

  BaggageAllowanceModel baggageAllowance(String pnr) =>
      const BaggageAllowanceModel(checkedKg: 30, cabinKg: 7);

  List<BaggageOptionModel> baggageOptions(String flightNumber) => _baggageOptions;

  /// Returns `null` if [simulatePaymentFailure] is set, mirroring a declined
  /// card at the payment gateway.
  BaggagePurchaseModel? purchaseBaggage({required String pnr, required String optionId}) {
    if (simulatePaymentFailure) return null;
    final option = _baggageOptions.firstWhere(
      (o) => o.id == optionId,
      orElse: () => _baggageOptions.first,
    );
    final purchase = BaggagePurchaseModel(
      id: 'purchase_${DateTime.now().millisecondsSinceEpoch}',
      option: option,
      status: 'success',
      confirmationCode: 'BG${_random.nextInt(90000) + 10000}',
    );
    purchaseHistory.add(purchase);
    return purchase;
  }

  // ---------------------------------------------------------------------
  // Airport
  // ---------------------------------------------------------------------
  AirportInfoModel airportInfo({required String flightNumber, required String airportCode}) {
    return const AirportInfoModel(
      terminal: '2',
      checkInCounter: '14-18',
      gate: 'B12',
      walkingTimeMinutes: 12,
      directions: [
        'Head to Check-in Row 14-18 on Level 2.',
        'Clear security and immigration.',
        'Follow signs to Gate B12 — approx. 12 min walk.',
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Chat / intent
  // ---------------------------------------------------------------------
  IntentResult classifyIntent(String utterance) {
    final lower = utterance.toLowerCase();
    if (lower.contains('seat')) {
      return const IntentResult(type: IntentType.seatSelection, confidence: 0.92);
    }
    if (lower.contains('baggage') || lower.contains('bag') || lower.contains('kg')) {
      return const IntentResult(type: IntentType.addBaggage, confidence: 0.88);
    }
    if (lower.contains('delay') || lower.contains('status') || lower.contains('flight')) {
      return const IntentResult(type: IntentType.flightStatus, confidence: 0.9);
    }
    if (lower.contains('terminal') || lower.contains('counter') || lower.contains('gate')) {
      return const IntentResult(type: IntentType.terminalInformation, confidence: 0.85);
    }
    if (lower.contains('agent') || lower.contains('human') || lower.contains('help me')) {
      return const IntentResult(type: IntentType.humanAgent, confidence: 0.8);
    }
    return const IntentResult(type: IntentType.faq, confidence: 0.4);
  }

  String generateReplyText(String utterance) {
    return "Here's what I found — let me know if you'd like more detail.";
  }

  int queuePosition = 2;
  int estimatedWaitMinutes = 4;
}
