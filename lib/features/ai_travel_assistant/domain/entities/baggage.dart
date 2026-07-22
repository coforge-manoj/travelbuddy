import 'package:equatable/equatable.dart';

enum BaggagePurchaseStatus { pending, success, failed }

class BaggageAllowance extends Equatable {
  const BaggageAllowance({
    required this.checkedKg,
    required this.cabinKg,
  });

  final num checkedKg;
  final num cabinKg;

  @override
  List<Object?> get props => [checkedKg, cabinKg];
}

class BaggageOption extends Equatable {
  const BaggageOption({
    required this.id,
    required this.extraWeightKg,
    required this.price,
    this.currency = 'USD',
  });

  final String id;
  final num extraWeightKg;
  final num price;
  final String currency;

  @override
  List<Object?> get props => [id, extraWeightKg, price, currency];
}

class BaggagePurchase extends Equatable {
  const BaggagePurchase({
    required this.id,
    required this.option,
    required this.status,
    this.confirmationCode,
  });

  final String id;
  final BaggageOption option;
  final BaggagePurchaseStatus status;
  final String? confirmationCode;

  @override
  List<Object?> get props => [id, option, status, confirmationCode];
}
