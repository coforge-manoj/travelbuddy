import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../utils/sample_data.dart';
import '../widgets/trip_card.dart';
import 'flight_search_screen.dart';
import 'flight_status_screen.dart';
import 'my_trips_screen.dart';
import 'travel_documents_screen.dart';
import 'airport_info_screen.dart';
import 'trip_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _HomeContent(),
    MyTripsScreen(),
    FlightStatusScreen(),
    TravelDocumentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_outlined),
            selectedIcon: Icon(Icons.flight),
            label: 'Flight Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Documents',
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final upcomingTrips = SampleData.trips
        .where((t) => t.status == TripStatus.upcoming)
        .toList();
    final nextTrip = upcomingTrips.isNotEmpty ? upcomingTrips.first : null;
    final daysUntilDeparture = nextTrip != null
        ? nextTrip.departureDate.difference(DateTime.now()).inDays
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TravelBuddy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Your Airline Travel Companion',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 24, bottom: 30),
                    child: Icon(
                      Icons.flight_takeoff,
                      size: 80,
                      color: Colors.white12,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nextTrip != null) ...[
                    _NextFlightBanner(
                      trip: nextTrip,
                      daysUntilDeparture: daysUntilDeparture!,
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const _QuickActionsGrid(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upcoming Trips',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyTripsScreen(),
                            ),
                          );
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  if (upcomingTrips.isEmpty)
                    const _EmptyTripsCard()
                  else
                    ...upcomingTrips.map(
                      (trip) => TripCard(
                        trip: trip,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailScreen(trip: trip),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  _TravelTipsCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextFlightBanner extends StatelessWidget {
  final Trip trip;
  final int daysUntilDeparture;

  const _NextFlightBanner({
    required this.trip,
    required this.daysUntilDeparture,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final flight = trip.firstFlight;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                daysUntilDeparture == 0
                    ? 'Today\'s Flight'
                    : daysUntilDeparture == 1
                        ? 'Tomorrow\'s Flight'
                        : 'Next Flight – $daysUntilDeparture days',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                flight.flightNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeFormat.format(flight.scheduledDeparture),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      flight.departureAirport,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      flight.departureCity,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.flight, color: Colors.white, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(flight.flightDuration),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeFormat.format(flight.scheduledArrival),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      flight.arrivalAirport,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      flight.arrivalCity,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (flight.gate != null || flight.terminal != null) ...[
            const Divider(color: Colors.white24, height: 20),
            Row(
              children: [
                if (flight.terminal != null) ...[
                  const Icon(Icons.business, size: 13, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text(
                    'Terminal ${flight.terminal}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                ],
                if (flight.gate != null) ...[
                  const Icon(Icons.door_front_door_outlined, size: 13, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text(
                    'Gate ${flight.gate}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                ],
                if (flight.seatNumber != null) ...[
                  const Icon(Icons.airline_seat_recline_normal, size: 13, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text(
                    'Seat ${flight.seatNumber}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        label: 'Search Flights',
        icon: Icons.search,
        color: const Color(0xFF1565C0),
        screen: const FlightSearchScreen(),
      ),
      _QuickAction(
        label: 'Flight Status',
        icon: Icons.radar,
        color: const Color(0xFF388E3C),
        screen: const FlightStatusScreen(),
      ),
      _QuickAction(
        label: 'Airport Info',
        icon: Icons.location_city,
        color: const Color(0xFF6A1B9A),
        screen: const AirportInfoScreen(),
      ),
      _QuickAction(
        label: 'Documents',
        icon: Icons.description_outlined,
        color: const Color(0xFFF57C00),
        screen: const TravelDocumentsScreen(),
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: actions
          .map(
            (action) => GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => action.screen),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.icon, color: action.color, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;

  _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class _EmptyTripsCard extends StatelessWidget {
  const _EmptyTripsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.flight_takeoff, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No upcoming trips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search for flights to plan your next adventure',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FlightSearchScreen()),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Search Flights'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelTipsCard extends StatelessWidget {
  static const List<Map<String, String>> _tips = [
    {
      'icon': '✈️',
      'tip': 'Arrive at least 2 hours early for domestic, 3 hours for international flights.',
    },
    {
      'icon': '🎒',
      'tip': 'Check your airline\'s baggage allowance before packing to avoid extra fees.',
    },
    {
      'icon': '📱',
      'tip': 'Download your airline\'s app and boarding pass for a seamless experience.',
    },
    {
      'icon': '💧',
      'tip': 'Stay hydrated during long flights — cabin air is very dry.',
    },
  ];

  const _TravelTipsCard();

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];

    return Card(
      color: const Color(0xFFE3F2FD),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tip['icon']!, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Travel Tip',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip['tip']!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
