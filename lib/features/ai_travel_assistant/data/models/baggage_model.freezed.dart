// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'baggage_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BaggageAllowanceModel _$BaggageAllowanceModelFromJson(
    Map<String, dynamic> json) {
  return _BaggageAllowanceModel.fromJson(json);
}

/// @nodoc
mixin _$BaggageAllowanceModel {
  num get checkedKg => throw _privateConstructorUsedError;
  num get cabinKg => throw _privateConstructorUsedError;

  /// Serializes this BaggageAllowanceModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BaggageAllowanceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BaggageAllowanceModelCopyWith<BaggageAllowanceModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BaggageAllowanceModelCopyWith<$Res> {
  factory $BaggageAllowanceModelCopyWith(BaggageAllowanceModel value,
          $Res Function(BaggageAllowanceModel) then) =
      _$BaggageAllowanceModelCopyWithImpl<$Res, BaggageAllowanceModel>;
  @useResult
  $Res call({num checkedKg, num cabinKg});
}

/// @nodoc
class _$BaggageAllowanceModelCopyWithImpl<$Res,
        $Val extends BaggageAllowanceModel>
    implements $BaggageAllowanceModelCopyWith<$Res> {
  _$BaggageAllowanceModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BaggageAllowanceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checkedKg = null,
    Object? cabinKg = null,
  }) {
    return _then(_value.copyWith(
      checkedKg: null == checkedKg
          ? _value.checkedKg
          : checkedKg // ignore: cast_nullable_to_non_nullable
              as num,
      cabinKg: null == cabinKg
          ? _value.cabinKg
          : cabinKg // ignore: cast_nullable_to_non_nullable
              as num,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BaggageAllowanceModelImplCopyWith<$Res>
    implements $BaggageAllowanceModelCopyWith<$Res> {
  factory _$$BaggageAllowanceModelImplCopyWith(
          _$BaggageAllowanceModelImpl value,
          $Res Function(_$BaggageAllowanceModelImpl) then) =
      __$$BaggageAllowanceModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({num checkedKg, num cabinKg});
}

/// @nodoc
class __$$BaggageAllowanceModelImplCopyWithImpl<$Res>
    extends _$BaggageAllowanceModelCopyWithImpl<$Res,
        _$BaggageAllowanceModelImpl>
    implements _$$BaggageAllowanceModelImplCopyWith<$Res> {
  __$$BaggageAllowanceModelImplCopyWithImpl(_$BaggageAllowanceModelImpl _value,
      $Res Function(_$BaggageAllowanceModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of BaggageAllowanceModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checkedKg = null,
    Object? cabinKg = null,
  }) {
    return _then(_$BaggageAllowanceModelImpl(
      checkedKg: null == checkedKg
          ? _value.checkedKg
          : checkedKg // ignore: cast_nullable_to_non_nullable
              as num,
      cabinKg: null == cabinKg
          ? _value.cabinKg
          : cabinKg // ignore: cast_nullable_to_non_nullable
              as num,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BaggageAllowanceModelImpl extends _BaggageAllowanceModel {
  const _$BaggageAllowanceModelImpl(
      {required this.checkedKg, required this.cabinKg})
      : super._();

  factory _$BaggageAllowanceModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BaggageAllowanceModelImplFromJson(json);

  @override
  final num checkedKg;
  @override
  final num cabinKg;

  @override
  String toString() {
    return 'BaggageAllowanceModel(checkedKg: $checkedKg, cabinKg: $cabinKg)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BaggageAllowanceModelImpl &&
            (identical(other.checkedKg, checkedKg) ||
                other.checkedKg == checkedKg) &&
            (identical(other.cabinKg, cabinKg) || other.cabinKg == cabinKg));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, checkedKg, cabinKg);

  /// Create a copy of BaggageAllowanceModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BaggageAllowanceModelImplCopyWith<_$BaggageAllowanceModelImpl>
      get copyWith => __$$BaggageAllowanceModelImplCopyWithImpl<
          _$BaggageAllowanceModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BaggageAllowanceModelImplToJson(
      this,
    );
  }
}

abstract class _BaggageAllowanceModel extends BaggageAllowanceModel {
  const factory _BaggageAllowanceModel(
      {required final num checkedKg,
      required final num cabinKg}) = _$BaggageAllowanceModelImpl;
  const _BaggageAllowanceModel._() : super._();

  factory _BaggageAllowanceModel.fromJson(Map<String, dynamic> json) =
      _$BaggageAllowanceModelImpl.fromJson;

  @override
  num get checkedKg;
  @override
  num get cabinKg;

  /// Create a copy of BaggageAllowanceModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BaggageAllowanceModelImplCopyWith<_$BaggageAllowanceModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}

BaggageOptionModel _$BaggageOptionModelFromJson(Map<String, dynamic> json) {
  return _BaggageOptionModel.fromJson(json);
}

/// @nodoc
mixin _$BaggageOptionModel {
  String get id => throw _privateConstructorUsedError;
  num get extraWeightKg => throw _privateConstructorUsedError;
  num get price => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;

  /// Serializes this BaggageOptionModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BaggageOptionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BaggageOptionModelCopyWith<BaggageOptionModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BaggageOptionModelCopyWith<$Res> {
  factory $BaggageOptionModelCopyWith(
          BaggageOptionModel value, $Res Function(BaggageOptionModel) then) =
      _$BaggageOptionModelCopyWithImpl<$Res, BaggageOptionModel>;
  @useResult
  $Res call({String id, num extraWeightKg, num price, String currency});
}

/// @nodoc
class _$BaggageOptionModelCopyWithImpl<$Res, $Val extends BaggageOptionModel>
    implements $BaggageOptionModelCopyWith<$Res> {
  _$BaggageOptionModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BaggageOptionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? extraWeightKg = null,
    Object? price = null,
    Object? currency = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      extraWeightKg: null == extraWeightKg
          ? _value.extraWeightKg
          : extraWeightKg // ignore: cast_nullable_to_non_nullable
              as num,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as num,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BaggageOptionModelImplCopyWith<$Res>
    implements $BaggageOptionModelCopyWith<$Res> {
  factory _$$BaggageOptionModelImplCopyWith(_$BaggageOptionModelImpl value,
          $Res Function(_$BaggageOptionModelImpl) then) =
      __$$BaggageOptionModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, num extraWeightKg, num price, String currency});
}

/// @nodoc
class __$$BaggageOptionModelImplCopyWithImpl<$Res>
    extends _$BaggageOptionModelCopyWithImpl<$Res, _$BaggageOptionModelImpl>
    implements _$$BaggageOptionModelImplCopyWith<$Res> {
  __$$BaggageOptionModelImplCopyWithImpl(_$BaggageOptionModelImpl _value,
      $Res Function(_$BaggageOptionModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of BaggageOptionModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? extraWeightKg = null,
    Object? price = null,
    Object? currency = null,
  }) {
    return _then(_$BaggageOptionModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      extraWeightKg: null == extraWeightKg
          ? _value.extraWeightKg
          : extraWeightKg // ignore: cast_nullable_to_non_nullable
              as num,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as num,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BaggageOptionModelImpl extends _BaggageOptionModel {
  const _$BaggageOptionModelImpl(
      {required this.id,
      required this.extraWeightKg,
      required this.price,
      this.currency = 'USD'})
      : super._();

  factory _$BaggageOptionModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BaggageOptionModelImplFromJson(json);

  @override
  final String id;
  @override
  final num extraWeightKg;
  @override
  final num price;
  @override
  @JsonKey()
  final String currency;

  @override
  String toString() {
    return 'BaggageOptionModel(id: $id, extraWeightKg: $extraWeightKg, price: $price, currency: $currency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BaggageOptionModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.extraWeightKg, extraWeightKg) ||
                other.extraWeightKg == extraWeightKg) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, extraWeightKg, price, currency);

  /// Create a copy of BaggageOptionModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BaggageOptionModelImplCopyWith<_$BaggageOptionModelImpl> get copyWith =>
      __$$BaggageOptionModelImplCopyWithImpl<_$BaggageOptionModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BaggageOptionModelImplToJson(
      this,
    );
  }
}

abstract class _BaggageOptionModel extends BaggageOptionModel {
  const factory _BaggageOptionModel(
      {required final String id,
      required final num extraWeightKg,
      required final num price,
      final String currency}) = _$BaggageOptionModelImpl;
  const _BaggageOptionModel._() : super._();

  factory _BaggageOptionModel.fromJson(Map<String, dynamic> json) =
      _$BaggageOptionModelImpl.fromJson;

  @override
  String get id;
  @override
  num get extraWeightKg;
  @override
  num get price;
  @override
  String get currency;

  /// Create a copy of BaggageOptionModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BaggageOptionModelImplCopyWith<_$BaggageOptionModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BaggagePurchaseModel _$BaggagePurchaseModelFromJson(Map<String, dynamic> json) {
  return _BaggagePurchaseModel.fromJson(json);
}

/// @nodoc
mixin _$BaggagePurchaseModel {
  String get id => throw _privateConstructorUsedError;
  BaggageOptionModel get option => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get confirmationCode => throw _privateConstructorUsedError;

  /// Serializes this BaggagePurchaseModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BaggagePurchaseModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BaggagePurchaseModelCopyWith<BaggagePurchaseModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BaggagePurchaseModelCopyWith<$Res> {
  factory $BaggagePurchaseModelCopyWith(BaggagePurchaseModel value,
          $Res Function(BaggagePurchaseModel) then) =
      _$BaggagePurchaseModelCopyWithImpl<$Res, BaggagePurchaseModel>;
  @useResult
  $Res call(
      {String id,
      BaggageOptionModel option,
      String status,
      String? confirmationCode});

  $BaggageOptionModelCopyWith<$Res> get option;
}

/// @nodoc
class _$BaggagePurchaseModelCopyWithImpl<$Res,
        $Val extends BaggagePurchaseModel>
    implements $BaggagePurchaseModelCopyWith<$Res> {
  _$BaggagePurchaseModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BaggagePurchaseModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? option = null,
    Object? status = null,
    Object? confirmationCode = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      option: null == option
          ? _value.option
          : option // ignore: cast_nullable_to_non_nullable
              as BaggageOptionModel,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      confirmationCode: freezed == confirmationCode
          ? _value.confirmationCode
          : confirmationCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  /// Create a copy of BaggagePurchaseModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BaggageOptionModelCopyWith<$Res> get option {
    return $BaggageOptionModelCopyWith<$Res>(_value.option, (value) {
      return _then(_value.copyWith(option: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BaggagePurchaseModelImplCopyWith<$Res>
    implements $BaggagePurchaseModelCopyWith<$Res> {
  factory _$$BaggagePurchaseModelImplCopyWith(_$BaggagePurchaseModelImpl value,
          $Res Function(_$BaggagePurchaseModelImpl) then) =
      __$$BaggagePurchaseModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      BaggageOptionModel option,
      String status,
      String? confirmationCode});

  @override
  $BaggageOptionModelCopyWith<$Res> get option;
}

/// @nodoc
class __$$BaggagePurchaseModelImplCopyWithImpl<$Res>
    extends _$BaggagePurchaseModelCopyWithImpl<$Res, _$BaggagePurchaseModelImpl>
    implements _$$BaggagePurchaseModelImplCopyWith<$Res> {
  __$$BaggagePurchaseModelImplCopyWithImpl(_$BaggagePurchaseModelImpl _value,
      $Res Function(_$BaggagePurchaseModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of BaggagePurchaseModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? option = null,
    Object? status = null,
    Object? confirmationCode = freezed,
  }) {
    return _then(_$BaggagePurchaseModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      option: null == option
          ? _value.option
          : option // ignore: cast_nullable_to_non_nullable
              as BaggageOptionModel,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      confirmationCode: freezed == confirmationCode
          ? _value.confirmationCode
          : confirmationCode // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BaggagePurchaseModelImpl extends _BaggagePurchaseModel {
  const _$BaggagePurchaseModelImpl(
      {required this.id,
      required this.option,
      required this.status,
      this.confirmationCode})
      : super._();

  factory _$BaggagePurchaseModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BaggagePurchaseModelImplFromJson(json);

  @override
  final String id;
  @override
  final BaggageOptionModel option;
  @override
  final String status;
  @override
  final String? confirmationCode;

  @override
  String toString() {
    return 'BaggagePurchaseModel(id: $id, option: $option, status: $status, confirmationCode: $confirmationCode)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BaggagePurchaseModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.option, option) || other.option == option) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.confirmationCode, confirmationCode) ||
                other.confirmationCode == confirmationCode));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, option, status, confirmationCode);

  /// Create a copy of BaggagePurchaseModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BaggagePurchaseModelImplCopyWith<_$BaggagePurchaseModelImpl>
      get copyWith =>
          __$$BaggagePurchaseModelImplCopyWithImpl<_$BaggagePurchaseModelImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BaggagePurchaseModelImplToJson(
      this,
    );
  }
}

abstract class _BaggagePurchaseModel extends BaggagePurchaseModel {
  const factory _BaggagePurchaseModel(
      {required final String id,
      required final BaggageOptionModel option,
      required final String status,
      final String? confirmationCode}) = _$BaggagePurchaseModelImpl;
  const _BaggagePurchaseModel._() : super._();

  factory _BaggagePurchaseModel.fromJson(Map<String, dynamic> json) =
      _$BaggagePurchaseModelImpl.fromJson;

  @override
  String get id;
  @override
  BaggageOptionModel get option;
  @override
  String get status;
  @override
  String? get confirmationCode;

  /// Create a copy of BaggagePurchaseModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BaggagePurchaseModelImplCopyWith<_$BaggagePurchaseModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
