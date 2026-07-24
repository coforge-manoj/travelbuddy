import '../../../../core/enum/flight_input_type.dart';

class SummarizedInputResult {
  final String cleanedText;
  final FlightInputType inputType;

  const SummarizedInputResult({
    required this.cleanedText,
    required this.inputType,
  });
}