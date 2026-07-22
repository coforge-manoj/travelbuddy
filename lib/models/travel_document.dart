enum DocumentType { passport, visa, boardingPass, travelInsurance, hotelBooking, other }

class TravelDocument {
  final String id;
  final DocumentType type;
  final String title;
  final String? documentNumber;
  final DateTime? expiryDate;
  final DateTime? issueDate;
  final String? issuingCountry;
  final String? notes;
  final String? tripId;

  const TravelDocument({
    required this.id,
    required this.type,
    required this.title,
    this.documentNumber,
    this.expiryDate,
    this.issueDate,
    this.issuingCountry,
    this.notes,
    this.tripId,
  });

  String get typeLabel {
    switch (type) {
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.visa:
        return 'Visa';
      case DocumentType.boardingPass:
        return 'Boarding Pass';
      case DocumentType.travelInsurance:
        return 'Travel Insurance';
      case DocumentType.hotelBooking:
        return 'Hotel Booking';
      case DocumentType.other:
        return 'Document';
    }
  }

  String get typeIcon {
    switch (type) {
      case DocumentType.passport:
        return '🛂';
      case DocumentType.visa:
        return '📋';
      case DocumentType.boardingPass:
        return '🎫';
      case DocumentType.travelInsurance:
        return '🛡️';
      case DocumentType.hotelBooking:
        return '🏨';
      case DocumentType.other:
        return '📄';
    }
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 90;
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }
}
