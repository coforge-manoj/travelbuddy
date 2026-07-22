import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flight.dart';
import '../utils/sample_data.dart';
import '../widgets/flight_card.dart';

class FlightStatusScreen extends StatefulWidget {
  const FlightStatusScreen({super.key});

  @override
  State<FlightStatusScreen> createState() => _FlightStatusScreenState();
}

class _FlightStatusScreenState extends State<FlightStatusScreen> {
  final _flightNumberController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSearching = false;
  Flight? _foundFlight;
  bool _searched = false;

  @override
  void dispose() {
    _flightNumberController.dispose();
    super.dispose();
  }

  void _checkStatus() async {
    if (_flightNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a flight number')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _foundFlight = null;
      _searched = false;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final queryNumber = _flightNumberController.text.trim().toUpperCase().replaceAll(' ', '');
    Flight? found;

    for (final trip in SampleData.trips) {
      for (final flight in trip.flights) {
        if (flight.flightNumber.replaceAll(' ', '') == queryNumber) {
          found = flight;
          break;
        }
      }
      if (found != null) break;
    }

    found ??= _getMockFlight(queryNumber);

    setState(() {
      _isSearching = false;
      _foundFlight = found;
      _searched = true;
    });
  }

  Flight? _getMockFlight(String number) {
    final statuses = [
      FlightStatus.onTime,
      FlightStatus.delayed,
      FlightStatus.scheduled,
    ];
    final status = statuses[number.length % statuses.length];
    final departure = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      10,
      25,
    );

    if (number.length < 3) return null;

    return Flight(
      flightNumber: number,
      airline: _getAirline(number.substring(0, 2)),
      airlineCode: number.substring(0, 2),
      departureAirport: 'ORD',
      departureCity: 'Chicago',
      arrivalAirport: 'LAX',
      arrivalCity: 'Los Angeles',
      scheduledDeparture: departure,
      scheduledArrival: departure.add(const Duration(hours: 4, minutes: 15)),
      status: status,
      terminal: 'T2',
      gate: 'G5',
      delayMinutes: status == FlightStatus.delayed ? 35 : 0,
    );
  }

  String _getAirline(String code) {
    const airlines = {
      'AA': 'American Airlines',
      'UA': 'United Airlines',
      'DL': 'Delta Air Lines',
      'BA': 'British Airways',
      'LH': 'Lufthansa',
      'AF': 'Air France',
      'EK': 'Emirates',
      'SQ': 'Singapore Airlines',
    };
    return airlines[code.toUpperCase()] ?? 'Unknown Airline';
  }

  @override
  Widget build(BuildContext context) {
    final upcomingFlights = SampleData.trips
        .expand((t) => t.flights)
        .where((f) =>
            f.status != FlightStatus.arrived &&
            f.scheduledDeparture.isAfter(DateTime.now()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Flight Status')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check Flight Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _flightNumberController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Flight Number',
                        hintText: 'AA204',
                        prefixIcon: Icon(Icons.flight),
                        helperText: 'Enter the airline code and flight number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 2)),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.radar),
                        label: Text(_isSearching ? 'Checking...' : 'Check Status'),
                        onPressed: _isSearching ? null : _checkStatus,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_searched && _foundFlight == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text(
                        'Flight not found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check the flight number and try again',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else if (_foundFlight != null) ...[
              const Text(
                'Flight Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FlightCard(flight: _foundFlight!),
              _FlightStatusDetails(flight: _foundFlight!),
            ],
            if (upcomingFlights.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Your Upcoming Flights',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...upcomingFlights.map((f) => FlightCard(flight: f)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlightStatusDetails extends StatelessWidget {
  final Flight flight;

  const _FlightStatusDetails({required this.flight});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Card(
      color: flight.statusColor.withOpacity(0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: flight.statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  flight.status == FlightStatus.onTime ||
                          flight.status == FlightStatus.scheduled
                      ? Icons.check_circle
                      : flight.status == FlightStatus.delayed
                          ? Icons.warning_amber_rounded
                          : flight.status == FlightStatus.cancelled
                              ? Icons.cancel
                              : Icons.info_outline,
                  color: flight.statusColor,
                ),
                const SizedBox(width: 8),
                Text(
                  flight.statusLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: flight.statusColor,
                  ),
                ),
              ],
            ),
            if (flight.status == FlightStatus.delayed) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated departure: ${timeFormat.format(flight.scheduledDeparture.add(Duration(minutes: flight.delayMinutes)))}',
                style: TextStyle(color: flight.statusColor),
              ),
            ],
            if (flight.status == FlightStatus.cancelled) ...[
              const SizedBox(height: 8),
              const Text(
                'This flight has been cancelled. Please contact the airline for rebooking options.',
                style: TextStyle(color: Color(0xFFD32F2F)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
