class TripProfile {
  final String destination;

  final String country;

  final String continent;

  final String budget;

  final String duration;

  final String season;

  final String month;

  final String tripPurpose;

  final String travelStyle;

  final String travellerType;

  final int travellers;

  const TripProfile({
    required this.destination,
    required this.country,
    required this.continent,
    required this.budget,
    required this.duration,
    required this.season,
    required this.month,
    required this.tripPurpose,
    required this.travelStyle,
    required this.travellerType,
    required this.travellers,
  });

  factory TripProfile.fromJson(
      Map<String, dynamic> json) {
    return TripProfile(
      destination: json["destination"]?.toString() ?? "",

      country: json["country"]?.toString() ?? "",

      continent: json["continent"]?.toString() ?? "",

      budget: json["budget"]?.toString() ?? "",

      duration: json["duration"]?.toString() ?? "",

      season: json["season"]?.toString() ?? "",

      month: json["month"]?.toString() ?? "",

      tripPurpose:
      json["tripPurpose"]?.toString() ?? "",

      travelStyle:
      json["travelStyle"]?.toString() ?? "",

      travellerType:
      json["travellerType"]?.toString() ?? "",

      travellers:
      (json["travellers"] as num?)?.toInt() ?? 1,
    );
  }

  factory TripProfile.empty() {
    return const TripProfile(
      destination: "",
      country: "",
      continent: "",
      budget: "",
      duration: "",
      season: "",
      month: "",
      tripPurpose: "",
      travelStyle: "",
      travellerType: "",
      travellers: 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "destination": destination,
      "country": country,
      "continent": continent,
      "budget": budget,
      "duration": duration,
      "season": season,
      "month": month,
      "tripPurpose": tripPurpose,
      "travelStyle": travelStyle,
      "travellerType": travellerType,
      "travellers": travellers,
    };
  }
}