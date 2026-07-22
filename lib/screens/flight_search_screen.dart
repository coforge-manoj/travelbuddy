import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flight.dart';
import '../widgets/flight_card.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTime _departureDate = DateTime.now().add(const Duration(days: 7));
  DateTime? _returnDate;
  int _passengers = 1;
  String _travelClass = 'Economy';
  bool _isSearching = false;
  List<Flight>? _searchResults;

  final List<String> _travelClasses = ['Economy', 'Premium Economy', 'Business', 'First'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _searchFlights() async {
    if (_originController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter origin and destination airports')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      _searchResults = _getMockResults();
    });
  }

  List<Flight> _getMockResults() {
    final departure = DateTime(
      _departureDate.year,
      _departureDate.month,
      _departureDate.day,
      8,
      30,
    );
    return [
      Flight(
        flightNumber: 'AA 101',
        airline: 'American Airlines',
        airlineCode: 'AA',
        departureAirport: _originController.text.toUpperCase(),
        departureCity: _originController.text,
        arrivalAirport: _destinationController.text.toUpperCase(),
        arrivalCity: _destinationController.text,
        scheduledDeparture: departure,
        scheduledArrival: departure.add(const Duration(hours: 7, minutes: 30)),
        status: FlightStatus.scheduled,
        terminal: 'T3',
        gate: 'B14',
      ),
      Flight(
        flightNumber: 'UA 302',
        airline: 'United Airlines',
        airlineCode: 'UA',
        departureAirport: _originController.text.toUpperCase(),
        departureCity: _originController.text,
        arrivalAirport: _destinationController.text.toUpperCase(),
        arrivalCity: _destinationController.text,
        scheduledDeparture: departure.add(const Duration(hours: 2)),
        scheduledArrival: departure.add(const Duration(hours: 10)),
        status: FlightStatus.scheduled,
        terminal: 'T1',
        gate: 'A7',
      ),
      Flight(
        flightNumber: 'DL 450',
        airline: 'Delta Air Lines',
        airlineCode: 'DL',
        departureAirport: _originController.text.toUpperCase(),
        departureCity: _originController.text,
        arrivalAirport: _destinationController.text.toUpperCase(),
        arrivalCity: _destinationController.text,
        scheduledDeparture: departure.add(const Duration(hours: 5)),
        scheduledArrival: departure.add(const Duration(hours: 12, minutes: 45)),
        status: FlightStatus.scheduled,
        terminal: 'T2',
        gate: 'C9',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Flights'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'One Way'),
            Tab(text: 'Round Trip'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _originController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'From',
                          hintText: 'JFK',
                          prefixIcon: Icon(Icons.flight_takeoff),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () {
                        final temp = _originController.text;
                        setState(() {
                          _originController.text = _destinationController.text;
                          _destinationController.text = temp;
                        });
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'To',
                          hintText: 'LHR',
                          prefixIcon: Icon(Icons.flight_land),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          DateFormat('d MMM').format(_departureDate),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _departureDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _departureDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_tabController.index == 1)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _returnDate != null
                              ? DateFormat('d MMM').format(_returnDate!)
                              : 'Return',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _returnDate ?? _departureDate.add(const Duration(days: 7)),
                            firstDate: _departureDate,
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _returnDate = picked);
                          }
                        },
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$_passengers',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Text('Passenger${_passengers > 1 ? 's' : ''}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: _passengers > 1
                                ? () => setState(() => _passengers--)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: _passengers < 9
                                ? () => setState(() => _passengers++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _travelClass,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _travelClasses
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _travelClass = v!),
                      ),
                    ),
                  ],
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
                        : const Icon(Icons.search),
                    label: Text(_isSearching ? 'Searching...' : 'Search Flights'),
                    onPressed: _isSearching ? null : _searchFlights,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Search for available flights',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your origin, destination and date',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_searchResults!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No flights found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) {
        final flight = _searchResults![index];
        return FlightCard(
          flight: flight,
          showStatus: false,
          onTap: () => _showFlightDetails(flight),
        );
      },
    );
  }

  void _showFlightDetails(Flight flight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${flight.flightNumber} – ${flight.airline}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FlightCard(flight: flight, showStatus: false),
              const SizedBox(height: 16),
              _DetailRow(label: 'Passengers', value: '$_passengers'),
              _DetailRow(label: 'Class', value: _travelClass),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${flight.flightNumber} selected. Proceed to booking.'),
                      ),
                    );
                  },
                  child: const Text('Select Flight'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
