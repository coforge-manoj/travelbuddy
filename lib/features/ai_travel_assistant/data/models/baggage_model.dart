import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/baggage.dart';

part 'baggage_model.freezed.dart';
part 'baggage_model.g.dart';

@freezed
class BaggageAllowanceModel with _$BaggageAllowanceModel {
  const BaggageAllowanceModel._();

  const factory BaggageAllowanceModel({
    required num checkedKg,
    required num cabinKg,
  }) = _BaggageAllowanceModel;

  factory BaggageAllowanceModel.fromJson(Map<String, dynamic> json) =>
      _$BaggageAllowanceModelFromJson(json);

  BaggageAllowance toEntity() => BaggageAllowance(checkedKg: checkedKg, cabinKg: cabinKg);
}

@freezed
class BaggageOptionModel with _$BaggageOptionModel {
  const BaggageOptionModel._();

  const factory BaggageOptionModel({
    required String id,
    required num extraWeightKg,
    required num price,
    @Default('USD') String currency,
  }) = _BaggageOptionModel;

  factory BaggageOptionModel.fromJson(Map<String, dynamic> json) =>
      _$BaggageOptionModelFromJson(json);

  BaggageOption toEntity() =>
      BaggageOption(id: id, extraWeightKg: extraWeightKg, price: price, currency: currency);
}

@freezed
class BaggagePurchaseModel with _$BaggagePurchaseModel {
  const BaggagePurchaseModel._();

  const factory BaggagePurchaseModel({
    required String id,
    required BaggageOptionModel option,
    required String status,
    String? confirmationCode,
  }) = _BaggagePurchaseModel;

  factory BaggagePurchaseModel.fromJson(Map<String, dynamic> json) =>
      _$BaggagePurchaseModelFromJson(json);

  BaggagePurchase toEntity() {
    return BaggagePurchase(
      id: id,
      option: option.toEntity(),
      status: BaggagePurchaseStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => BaggagePurchaseStatus.failed,
      ),
      confirmationCode: confirmationCode,
    );
  }
}
