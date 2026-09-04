import 'package:equatable/equatable.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/basket.dart';

/// The `extras_list` card: the ancillaries available for a cabin, with the
/// ones that cabin already includes marked. Reuses [BasketExtra] for the
/// rows — the same wifi/bag/lounge entries appear on the basket once added.
class ExtrasCatalogue extends Equatable {
  const ExtrasCatalogue({
    required this.extras,
    this.cabin = '',
    this.currency = 'USD',
  });

  final List<BasketExtra> extras;
  final String cabin;
  final String currency;

  @override
  List<Object?> get props => [extras, cabin, currency];
}
