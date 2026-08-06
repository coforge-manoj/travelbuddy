class HumanizedResponse {
  final String message;

  final dynamic payload;

  const HumanizedResponse({
    required this.message,
    this.payload,
  });

  factory HumanizedResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    return HumanizedResponse(
      message: json['message']?.toString() ?? '',
      payload: json['payload'],
    );
  }
}