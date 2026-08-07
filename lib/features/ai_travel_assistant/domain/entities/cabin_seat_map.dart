import 'package:equatable/equatable.dart';

/// The `seat_map` card: cabins, rows, availability and prices, as returned
/// by the chat backend.
///
/// Deliberately separate from the older [SeatMap] in `seat.dart`, which
/// models the mock backend's flat single-cabin grid. This one keeps the
/// backend's own cabin grouping and its seat labels as strings, because the
/// live map prices seats per cabin and does not promise a rectangular grid.
class CabinSeatMap extends Equatable {
  const CabinSeatMap({
    required this.cabins,
    this.flightNumber = '',
    this.currency = 'USD',
    this.currentSeat,
  });

  final List<SeatCabin> cabins;
  final String flightNumber;
  final String currency;

  /// The seat the passenger already holds, so the map can mark it.
  final String? currentSeat;

  bool get isEmpty => cabins.every((cabin) => cabin.seats.isEmpty);

  @override
  List<Object?> get props => [cabins, flightNumber, currency, currentSeat];
}

class SeatCabin extends Equatable {
  const SeatCabin({required this.name, required this.seats});

  final String name;
  final List<CabinSeat> seats;

  /// Seats keyed by row, in the order the backend listed them.
  Map<int, List<CabinSeat>> get seatsByRow {
    final rows = <int, List<CabinSeat>>{};
    for (final seat in seats) {
      rows.putIfAbsent(seat.row, () => <CabinSeat>[]).add(seat);
    }
    return rows;
  }

  @override
  List<Object?> get props => [name, seats];
}

class CabinSeat extends Equatable {
  const CabinSeat({
    required this.seatNumber,
    required this.row,
    required this.column,
    this.available = true,
    this.price = 0,
    this.type,
    this.isExitRow = false,
  });

  final String seatNumber;
  final int row;
  final String column;
  final bool available;
  final num price;

  /// `window` / `middle` / `aisle` when the backend says; kept as a string
  /// so an unknown value renders rather than being dropped.
  final String? type;
  final bool isExitRow;

  @override
  List<Object?> get props =>
      [seatNumber, row, column, available, price, type, isExitRow];
}
