# TravelBuddy – Airline Travel Companion

TravelBuddy is a Flutter mobile application that serves as your complete airline travel companion. It helps you manage flights, track statuses, organise travel documents, and discover airport information.

## Features

### ✈️ Flight Search
- Search for one-way or round-trip flights
- Filter by travel class (Economy, Premium Economy, Business, First)
- Select number of passengers
- View flight results with duration, schedule, and airline info

### 📡 Flight Status
- Real-time flight status lookup by flight number and date
- Status indicators: On Time, Delayed (with delay minutes), Cancelled, Departed, Arrived
- View all your upcoming flights at a glance

### 🧳 My Trips
- Organise trips into Upcoming, Completed, and Cancelled tabs
- View full trip details including all flights and passenger info
- Booking reference management

### 📄 Travel Documents
- Store passports, visas, boarding passes, travel insurance, hotel bookings
- Automatic expiry alerts: expired and expiring-within-90-days warnings
- Add and manage documents with type, number, and expiry date

### 🏢 Airport Info
- Search airports by name, code, city, or country
- View terminals, transport options, and amenities
- Amenity details including location and operating hours

### 🏠 Home Dashboard
- Next flight banner with departure countdown
- Quick action shortcuts
- Daily travel tips
- Upcoming trips summary

## Project Structure

```
lib/
├── main.dart                    # App entry point & theme
├── models/
│   ├── flight.dart              # Flight model with status
│   ├── trip.dart                # Trip & passenger models
│   ├── airport.dart             # Airport & amenity models
│   └── travel_document.dart     # Travel document model
├── screens/
│   ├── home_screen.dart         # Home dashboard
│   ├── flight_search_screen.dart
│   ├── flight_status_screen.dart
│   ├── my_trips_screen.dart
│   ├── trip_detail_screen.dart
│   ├── travel_documents_screen.dart
│   └── airport_info_screen.dart
├── widgets/
│   ├── flight_card.dart         # Reusable flight card widget
│   └── trip_card.dart           # Reusable trip card widget
└── utils/
    └── sample_data.dart         # Sample flights, airports, documents
```

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.10.0
- Dart SDK ≥ 3.0.0

### Running the App

```bash
flutter pub get
flutter run
```

### Running Tests

```bash
flutter test
```
