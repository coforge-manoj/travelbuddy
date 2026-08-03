class TripDiscoveryContext {
  final String? destination;
  final String? country;
  final String? month;
  final String? season;
  final String? budget;
  final String? duration;
  final String? travellerType;
  final String? tripPurpose;

  const TripDiscoveryContext({
    this.destination,
    this.country,
    this.month,
    this.season,
    this.budget,
    this.duration,
    this.travellerType,
    this.tripPurpose,
  });

  factory TripDiscoveryContext.fromJson(
      Map<String, dynamic> json,
      ) {
    return TripDiscoveryContext(
      destination: json["destination"]?.toString(),
      country: json["country"]?.toString(),
      month: json["month"]?.toString(),
      season: json["season"]?.toString(),
      budget: json["budget"]?.toString(),
      duration: json["duration"]?.toString(),
      travellerType: json["travellerType"]?.toString(),
      tripPurpose: json["tripPurpose"]?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "destination": destination,
      "country": country,
      "month": month,
      "season": season,
      "budget": budget,
      "duration": duration,
      "travellerType": travellerType,
      "tripPurpose": tripPurpose,
    };
  }

  TripDiscoveryContext copyWith({
    String? destination,
    String? country,
    String? month,
    String? season,
    String? budget,
    String? duration,
    String? travellerType,
    String? tripPurpose,
  }) {
    return TripDiscoveryContext(
      destination: destination ?? this.destination,
      country: country ?? this.country,
      month: month ?? this.month,
      season: season ?? this.season,
      budget: budget ?? this.budget,
      duration: duration ?? this.duration,
      travellerType: travellerType ?? this.travellerType,
      tripPurpose: tripPurpose ?? this.tripPurpose,
    );
  }
}