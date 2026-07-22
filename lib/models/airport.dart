class AirportAmenity {
  final String name;
  final String icon;
  final String location;
  final String? hours;

  const AirportAmenity({
    required this.name,
    required this.icon,
    required this.location,
    this.hours,
  });
}

class Airport {
  final String code;
  final String name;
  final String city;
  final String country;
  final String timezone;
  final int terminals;
  final List<AirportAmenity> amenities;
  final String? transportInfo;
  final String? websiteUrl;

  const Airport({
    required this.code,
    required this.name,
    required this.city,
    required this.country,
    required this.timezone,
    required this.terminals,
    required this.amenities,
    this.transportInfo,
    this.websiteUrl,
  });
}
