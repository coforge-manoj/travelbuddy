// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'baggage_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BaggageAllowanceModelImpl _$$BaggageAllowanceModelImplFromJson(
        Map<String, dynamic> json) =>
    _$BaggageAllowanceModelImpl(
      checkedKg: json['checkedKg'] as num,
      cabinKg: json['cabinKg'] as num,
    );

Map<String, dynamic> _$$BaggageAllowanceModelImplToJson(
        _$BaggageAllowanceModelImpl instance) =>
    <String, dynamic>{
      'checkedKg': instance.checkedKg,
      'cabinKg': instance.cabinKg,
    };

_$BaggageOptionModelImpl _$$BaggageOptionModelImplFromJson(
        Map<String, dynamic> json) =>
    _$BaggageOptionModelImpl(
      id: json['id'] as String,
      extraWeightKg: json['extraWeightKg'] as num,
      price: json['price'] as num,
      currency: json['currency'] as String? ?? 'USD',
    );

Map<String, dynamic> _$$BaggageOptionModelImplToJson(
        _$BaggageOptionModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'extraWeightKg': instance.extraWeightKg,
      'price': instance.price,
      'currency': instance.currency,
    };

_$BaggagePurchaseModelImpl _$$BaggagePurchaseModelImplFromJson(
        Map<String, dynamic> json) =>
    _$BaggagePurchaseModelImpl(
      id: json['id'] as String,
      option:
          BaggageOptionModel.fromJson(json['option'] as Map<String, dynamic>),
      status: json['status'] as String,
      confirmationCode: json['confirmationCode'] as String?,
    );

Map<String, dynamic> _$$BaggagePurchaseModelImplToJson(
        _$BaggagePurchaseModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'option': instance.option,
      'status': instance.status,
      'confirmationCode': instance.confirmationCode,
    };
