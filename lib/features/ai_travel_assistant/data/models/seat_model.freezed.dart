// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'seat_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SeatModel _$SeatModelFromJson(Map<String, dynamic> json) {
  return _SeatModel.fromJson(json);
}

/// @nodoc
mixin _$SeatModel {
  String get seatNumber => throw _privateConstructorUsedError;
  int get row => throw _privateConstructorUsedError;
  String get column => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get availability => throw _privateConstructorUsedError;
  num get priceDelta => throw _privateConstructorUsedError;
  bool get isExitRow => throw _privateConstructorUsedError;

  /// Serializes this SeatModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SeatModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeatModelCopyWith<SeatModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeatModelCopyWith<$Res> {
  factory $SeatModelCopyWith(SeatModel value, $Res Function(SeatModel) then) =
      _$SeatModelCopyWithImpl<$Res, SeatModel>;
  @useResult
  $Res call(
      {String seatNumber,
      int row,
      String column,
      String type,
      String availability,
      num priceDelta,
      bool isExitRow});
}

/// @nodoc
class _$SeatModelCopyWithImpl<$Res, $Val extends SeatModel>
    implements $SeatModelCopyWith<$Res> {
  _$SeatModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SeatModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seatNumber = null,
    Object? row = null,
    Object? column = null,
    Object? type = null,
    Object? availability = null,
    Object? priceDelta = null,
    Object? isExitRow = null,
  }) {
    return _then(_value.copyWith(
      seatNumber: null == seatNumber
          ? _value.seatNumber
          : seatNumber // ignore: cast_nullable_to_non_nullable
              as String,
      row: null == row
          ? _value.row
          : row // ignore: cast_nullable_to_non_nullable
              as int,
      column: null == column
          ? _value.column
          : column // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      availability: null == availability
          ? _value.availability
          : availability // ignore: cast_nullable_to_non_nullable
              as String,
      priceDelta: null == priceDelta
          ? _value.priceDelta
          : priceDelta // ignore: cast_nullable_to_non_nullable
              as num,
      isExitRow: null == isExitRow
          ? _value.isExitRow
          : isExitRow // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SeatModelImplCopyWith<$Res>
    implements $SeatModelCopyWith<$Res> {
  factory _$$SeatModelImplCopyWith(
          _$SeatModelImpl value, $Res Function(_$SeatModelImpl) then) =
      __$$SeatModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String seatNumber,
      int row,
      String column,
      String type,
      String availability,
      num priceDelta,
      bool isExitRow});
}

/// @nodoc
class __$$SeatModelImplCopyWithImpl<$Res>
    extends _$SeatModelCopyWithImpl<$Res, _$SeatModelImpl>
    implements _$$SeatModelImplCopyWith<$Res> {
  __$$SeatModelImplCopyWithImpl(
      _$SeatModelImpl _value, $Res Function(_$SeatModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of SeatModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seatNumber = null,
    Object? row = null,
    Object? column = null,
    Object? type = null,
    Object? availability = null,
    Object? priceDelta = null,
    Object? isExitRow = null,
  }) {
    return _then(_$SeatModelImpl(
      seatNumber: null == seatNumber
          ? _value.seatNumber
          : seatNumber // ignore: cast_nullable_to_non_nullable
              as String,
      row: null == row
          ? _value.row
          : row // ignore: cast_nullable_to_non_nullable
              as int,
      column: null == column
          ? _value.column
          : column // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      availability: null == availability
          ? _value.availability
          : availability // ignore: cast_nullable_to_non_nullable
              as String,
      priceDelta: null == priceDelta
          ? _value.priceDelta
          : priceDelta // ignore: cast_nullable_to_non_nullable
              as num,
      isExitRow: null == isExitRow
          ? _value.isExitRow
          : isExitRow // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SeatModelImpl extends _SeatModel {
  const _$SeatModelImpl(
      {required this.seatNumber,
      required this.row,
      required this.column,
      required this.type,
      required this.availability,
      this.priceDelta = 0,
      this.isExitRow = false})
      : super._();

  factory _$SeatModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeatModelImplFromJson(json);

  @override
  final String seatNumber;
  @override
  final int row;
  @override
  final String column;
  @override
  final String type;
  @override
  final String availability;
  @override
  @JsonKey()
  final num priceDelta;
  @override
  @JsonKey()
  final bool isExitRow;

  @override
  String toString() {
    return 'SeatModel(seatNumber: $seatNumber, row: $row, column: $column, type: $type, availability: $availability, priceDelta: $priceDelta, isExitRow: $isExitRow)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeatModelImpl &&
            (identical(other.seatNumber, seatNumber) ||
                other.seatNumber == seatNumber) &&
            (identical(other.row, row) || other.row == row) &&
            (identical(other.column, column) || other.column == column) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.availability, availability) ||
                other.availability == availability) &&
            (identical(other.priceDelta, priceDelta) ||
                other.priceDelta == priceDelta) &&
            (identical(other.isExitRow, isExitRow) ||
                other.isExitRow == isExitRow));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seatNumber, row, column, type,
      availability, priceDelta, isExitRow);

  /// Create a copy of SeatModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeatModelImplCopyWith<_$SeatModelImpl> get copyWith =>
      __$$SeatModelImplCopyWithImpl<_$SeatModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeatModelImplToJson(
      this,
    );
  }
}

abstract class _SeatModel extends SeatModel {
  const factory _SeatModel(
      {required final String seatNumber,
      required final int row,
      required final String column,
      required final String type,
      required final String availability,
      final num priceDelta,
      final bool isExitRow}) = _$SeatModelImpl;
  const _SeatModel._() : super._();

  factory _SeatModel.fromJson(Map<String, dynamic> json) =
      _$SeatModelImpl.fromJson;

  @override
  String get seatNumber;
  @override
  int get row;
  @override
  String get column;
  @override
  String get type;
  @override
  String get availability;
  @override
  num get priceDelta;
  @override
  bool get isExitRow;

  /// Create a copy of SeatModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeatModelImplCopyWith<_$SeatModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SeatMapModel _$SeatMapModelFromJson(Map<String, dynamic> json) {
  return _SeatMapModel.fromJson(json);
}

/// @nodoc
mixin _$SeatMapModel {
  String get flightNumber => throw _privateConstructorUsedError;
  int get rows => throw _privateConstructorUsedError;
  List<SeatModel> get seats => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;

  /// Serializes this SeatMapModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SeatMapModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeatMapModelCopyWith<SeatMapModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeatMapModelCopyWith<$Res> {
  factory $SeatMapModelCopyWith(
          SeatMapModel value, $Res Function(SeatMapModel) then) =
      _$SeatMapModelCopyWithImpl<$Res, SeatMapModel>;
  @useResult
  $Res call(
      {String flightNumber, int rows, List<SeatModel> seats, String currency});
}

/// @nodoc
class _$SeatMapModelCopyWithImpl<$Res, $Val extends SeatMapModel>
    implements $SeatMapModelCopyWith<$Res> {
  _$SeatMapModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SeatMapModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flightNumber = null,
    Object? rows = null,
    Object? seats = null,
    Object? currency = null,
  }) {
    return _then(_value.copyWith(
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      rows: null == rows
          ? _value.rows
          : rows // ignore: cast_nullable_to_non_nullable
              as int,
      seats: null == seats
          ? _value.seats
          : seats // ignore: cast_nullable_to_non_nullable
              as List<SeatModel>,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SeatMapModelImplCopyWith<$Res>
    implements $SeatMapModelCopyWith<$Res> {
  factory _$$SeatMapModelImplCopyWith(
          _$SeatMapModelImpl value, $Res Function(_$SeatMapModelImpl) then) =
      __$$SeatMapModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String flightNumber, int rows, List<SeatModel> seats, String currency});
}

/// @nodoc
class __$$SeatMapModelImplCopyWithImpl<$Res>
    extends _$SeatMapModelCopyWithImpl<$Res, _$SeatMapModelImpl>
    implements _$$SeatMapModelImplCopyWith<$Res> {
  __$$SeatMapModelImplCopyWithImpl(
      _$SeatMapModelImpl _value, $Res Function(_$SeatMapModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of SeatMapModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flightNumber = null,
    Object? rows = null,
    Object? seats = null,
    Object? currency = null,
  }) {
    return _then(_$SeatMapModelImpl(
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      rows: null == rows
          ? _value.rows
          : rows // ignore: cast_nullable_to_non_nullable
              as int,
      seats: null == seats
          ? _value._seats
          : seats // ignore: cast_nullable_to_non_nullable
              as List<SeatModel>,
      currency: null == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SeatMapModelImpl extends _SeatMapModel {
  const _$SeatMapModelImpl(
      {required this.flightNumber,
      required this.rows,
      required final List<SeatModel> seats,
      this.currency = 'USD'})
      : _seats = seats,
        super._();

  factory _$SeatMapModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeatMapModelImplFromJson(json);

  @override
  final String flightNumber;
  @override
  final int rows;
  final List<SeatModel> _seats;
  @override
  List<SeatModel> get seats {
    if (_seats is EqualUnmodifiableListView) return _seats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_seats);
  }

  @override
  @JsonKey()
  final String currency;

  @override
  String toString() {
    return 'SeatMapModel(flightNumber: $flightNumber, rows: $rows, seats: $seats, currency: $currency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeatMapModelImpl &&
            (identical(other.flightNumber, flightNumber) ||
                other.flightNumber == flightNumber) &&
            (identical(other.rows, rows) || other.rows == rows) &&
            const DeepCollectionEquality().equals(other._seats, _seats) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, flightNumber, rows,
      const DeepCollectionEquality().hash(_seats), currency);

  /// Create a copy of SeatMapModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeatMapModelImplCopyWith<_$SeatMapModelImpl> get copyWith =>
      __$$SeatMapModelImplCopyWithImpl<_$SeatMapModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeatMapModelImplToJson(
      this,
    );
  }
}

abstract class _SeatMapModel extends SeatMapModel {
  const factory _SeatMapModel(
      {required final String flightNumber,
      required final int rows,
      required final List<SeatModel> seats,
      final String currency}) = _$SeatMapModelImpl;
  const _SeatMapModel._() : super._();

  factory _SeatMapModel.fromJson(Map<String, dynamic> json) =
      _$SeatMapModelImpl.fromJson;

  @override
  String get flightNumber;
  @override
  int get rows;
  @override
  List<SeatModel> get seats;
  @override
  String get currency;

  /// Create a copy of SeatMapModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeatMapModelImplCopyWith<_$SeatMapModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
