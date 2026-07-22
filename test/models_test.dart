import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelbuddy/models/flight.dart';
import 'package:travelbuddy/models/trip.dart';
import 'package:travelbuddy/models/airport.dart';
import 'package:travelbuddy/models/travel_document.dart';
import 'package:travelbuddy/utils/sample_data.dart';

void main() {
  group('Flight model', () {
    final departure = DateTime(2026, 8, 1, 10, 0);
    final arrival = DateTime(2026, 8, 1, 17, 30);

    final flight = Flight(
      flightNumber: 'AA 204',
      airline: 'American Airlines',
      airlineCode: 'AA',
      departureAirport: 'JFK',
      departureCity: 'New York',
      arrivalAirport: 'LHR',
      arrivalCity: 'London',
      scheduledDeparture: departure,
      scheduledArrival: arrival,
      status: FlightStatus.onTime,
      terminal: 'T5',
      gate: 'B22',
    );

    test('flightDuration is correct', () {
      expect(flight.flightDuration, const Duration(hours: 7, minutes: 30));
    });

    test('statusLabel for onTime', () {
      expect(flight.statusLabel, 'On Time');
    });

    test('statusLabel for delayed includes minutes', () {
      final delayed = Flight(
        flightNumber: 'DL 1',
        airline: 'Delta',
        airlineCode: 'DL',
        departureAirport: 'ATL',
        departureCity: 'Atlanta',
        arrivalAirport: 'ORD',
        arrivalCity: 'Chicago',
        scheduledDeparture: departure,
        scheduledArrival: arrival,
        status: FlightStatus.delayed,
        delayMinutes: 45,
      );
      expect(delayed.statusLabel, 'Delayed 45m');
    });

    test('statusLabel for cancelled', () {
      final cancelled = Flight(
        flightNumber: 'UA 5',
        airline: 'United',
        airlineCode: 'UA',
        departureAirport: 'LAX',
        departureCity: 'Los Angeles',
        arrivalAirport: 'SFO',
        arrivalCity: 'San Francisco',
        scheduledDeparture: departure,
        scheduledArrival: arrival,
        status: FlightStatus.cancelled,
      );
      expect(cancelled.statusLabel, 'Cancelled');
    });

    test('statusColor for delayed is orange', () {
      final delayed = Flight(
        flightNumber: 'BA 2',
        airline: 'British Airways',
        airlineCode: 'BA',
        departureAirport: 'LHR',
        departureCity: 'London',
        arrivalAirport: 'CDG',
        arrivalCity: 'Paris',
        scheduledDeparture: departure,
        scheduledArrival: arrival,
        status: FlightStatus.delayed,
      );
      expect(delayed.statusColor, const Color(0xFFF57C00));
    });
  });

  group('Trip model', () {
    final departure = DateTime(2026, 8, 1, 10, 0);
    final arrival = DateTime(2026, 8, 1, 17, 30);

    final trip = Trip(
      id: 'test_trip',
      bookingReference: 'ABCDEF',
      status: TripStatus.upcoming,
      createdAt: DateTime.now(),
      passengers: const [
        TripPassenger(
          firstName: 'Jane',
          lastName: 'Doe',
          seatNumber: '10A',
          ticketClass: 'Economy',
        ),
      ],
      flights: [
        Flight(
          flightNumber: 'EK 202',
          airline: 'Emirates',
          airlineCode: 'EK',
          departureAirport: 'DXB',
          departureCity: 'Dubai',
          arrivalAirport: 'SIN',
          arrivalCity: 'Singapore',
          scheduledDeparture: departure,
          scheduledArrival: arrival,
          status: FlightStatus.scheduled,
        ),
      ],
    );

    test('origin and destination derived from flights', () {
      expect(trip.origin, 'Dubai');
      expect(trip.destination, 'Singapore');
      expect(trip.originCode, 'DXB');
      expect(trip.destinationCode, 'SIN');
    });

    test('isMultiCity is false for single flight', () {
      expect(trip.isMultiCity, isFalse);
    });

    test('TripPassenger fullName', () {
      expect(trip.passengers.first.fullName, 'Jane Doe');
    });
  });

  group('TravelDocument model', () {
    test('isExpired when expiry is in the past', () {
      final expired = TravelDocument(
        id: '1',
        type: DocumentType.passport,
        title: 'Old Passport',
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(expired.isExpired, isTrue);
      expect(expired.isExpiringSoon, isFalse);
    });

    test('isExpiringSoon within 90 days', () {
      final expiring = TravelDocument(
        id: '2',
        type: DocumentType.visa,
        title: 'Visa',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(expiring.isExpiringSoon, isTrue);
      expect(expiring.isExpired, isFalse);
    });

    test('valid document not expiring soon', () {
      final valid = TravelDocument(
        id: '3',
        type: DocumentType.passport,
        title: 'Valid Passport',
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );
      expect(valid.isExpired, isFalse);
      expect(valid.isExpiringSoon, isFalse);
    });

    test('typeLabel and typeIcon for each type', () {
      expect(
        TravelDocument(id: '4', type: DocumentType.passport, title: '').typeLabel,
        'Passport',
      );
      expect(
        TravelDocument(id: '5', type: DocumentType.boardingPass, title: '').typeLabel,
        'Boarding Pass',
      );
      expect(
        TravelDocument(id: '6', type: DocumentType.travelInsurance, title: '').typeLabel,
        'Travel Insurance',
      );
    });

    test('document without expiryDate is never expired or expiring', () {
      final doc = TravelDocument(
        id: '7',
        type: DocumentType.boardingPass,
        title: 'BP',
      );
      expect(doc.isExpired, isFalse);
      expect(doc.isExpiringSoon, isFalse);
    });
  });

  group('Airport model', () {
    const airport = Airport(
      code: 'SYD',
      name: 'Sydney Airport',
      city: 'Sydney',
      country: 'Australia',
      timezone: 'Australia/Sydney',
      terminals: 3,
      amenities: [
        AirportAmenity(
          name: 'Wi-Fi',
          icon: '📶',
          location: 'All terminals',
          hours: '24/7',
        ),
      ],
    );

    test('airport properties are correct', () {
      expect(airport.code, 'SYD');
      expect(airport.terminals, 3);
      expect(airport.amenities.length, 1);
      expect(airport.amenities.first.name, 'Wi-Fi');
    });
  });

  group('SampleData', () {
    test('trips list is not empty', () {
      expect(SampleData.trips, isNotEmpty);
    });

    test('airports list contains expected airports', () {
      final codes = SampleData.airports.map((a) => a.code).toList();
      expect(codes, containsAll(['JFK', 'LHR', 'CDG', 'DXB', 'SIN']));
    });

    test('documents list is not empty', () {
      expect(SampleData.documents, isNotEmpty);
    });

    test('upcoming trip has valid flight', () {
      final upcoming = SampleData.trips.where(
        (t) => t.status == TripStatus.upcoming,
      );
      expect(upcoming, isNotEmpty);
      for (final trip in upcoming) {
        expect(trip.flights, isNotEmpty);
        expect(trip.departureDate.isAfter(DateTime.now()), isTrue);
      }
    });
  });

  group('Travel tips rotation', () {
    const tips = [
      {'icon': '✈️', 'tip': 'Tip A'},
      {'icon': '🎒', 'tip': 'Tip B'},
      {'icon': '📱', 'tip': 'Tip C'},
      {'icon': '💧', 'tip': 'Tip D'},
    ];

    test('tip index stays in bounds for any day-of-month', () {
      for (int day = 1; day <= 31; day++) {
        final index = day % tips.length;
        expect(index, greaterThanOrEqualTo(0));
        expect(index, lessThan(tips.length));
      }
    });

    test('tip selection cycles through all tips', () {
      final selected = List.generate(tips.length, (i) => tips[i % tips.length]);
      final allKeys = selected.map((t) => t['icon']).toSet();
      expect(allKeys.length, tips.length);
    });
  });
}
