import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../utils/sample_data.dart';
import '../widgets/trip_card.dart';
import 'trip_detail_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = SampleData.trips
        .where((t) => t.status == TripStatus.upcoming || t.status == TripStatus.active)
        .toList();
    final completed = SampleData.trips
        .where((t) => t.status == TripStatus.completed)
        .toList();
    final cancelled = SampleData.trips
        .where((t) => t.status == TripStatus.cancelled)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Upcoming (${upcoming.length})'),
            Tab(text: 'Completed (${completed.length})'),
            Tab(text: 'Cancelled (${cancelled.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TripsList(trips: upcoming, emptyMessage: 'No upcoming trips'),
          _TripsList(trips: completed, emptyMessage: 'No completed trips'),
          _TripsList(trips: cancelled, emptyMessage: 'No cancelled trips'),
        ],
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  final List<Trip> trips;
  final String emptyMessage;

  const _TripsList({required this.trips, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          trip: trip,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(trip: trip),
              ),
            );
          },
        );
      },
    );
  }
}
