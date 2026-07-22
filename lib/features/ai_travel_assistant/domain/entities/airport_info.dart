import 'package:equatable/equatable.dart';

class AirportInfo extends Equatable {
  const AirportInfo({
    required this.terminal,
    required this.checkInCounter,
    required this.gate,
    required this.walkingTimeMinutes,
    this.indoorMapAssetPath,
    this.directions = const [],
  });

  final String terminal;
  final String checkInCounter;
  final String gate;
  final int walkingTimeMinutes;

  /// Placeholder for an indoor-map asset/URL; real indoor mapping is out of
  /// scope for this module and is left as an integration point.
  final String? indoorMapAssetPath;
  final List<String> directions;

  @override
  List<Object?> get props =>
      [terminal, checkInCounter, gate, walkingTimeMinutes, indoorMapAssetPath, directions];
}
