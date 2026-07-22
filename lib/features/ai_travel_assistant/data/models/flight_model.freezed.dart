// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'flight_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FlightModel _$FlightModelFromJson(Map<String, dynamic> json) {
  return _FlightModel.fromJson(json);
}

/// @nodoc
mixin _$FlightModel {
  String get flightNumber => throw _privateConstructorUsedError;
  String get origin => throw _privateConstructorUsedError;
  String get destination => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get scheduledDeparture => throw _privateConstructorUsedError;
  String? get estimatedDeparture => throw _privateConstructorUsedError;
  String? get gate => throw _privateConstructorUsedError;
  String? get terminal => throw _privateConstructorUsedError;
  String? get checkInCounter => throw _privateConstructorUsedError;
  String? get boardingTime => throw _privateConstructorUsedError;

  /// Serializes this FlightModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FlightModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FlightModelCopyWith<FlightModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FlightModelCopyWith<$Res> {
  factory $FlightModelCopyWith(
          FlightModel value, $Res Function(FlightModel) then) =
      _$FlightModelCopyWithImpl<$Res, FlightModel>;
  @useResult
  $Res call(
      {String flightNumber,
      String origin,
      String destination,
      String status,
      String scheduledDeparture,
      String? estimatedDeparture,
      String? gate,
      String? terminal,
      String? checkInCounter,
      String? boardingTime});
}

/// @nodoc
class _$FlightModelCopyWithImpl<$Res, $Val extends FlightModel>
    implements $FlightModelCopyWith<$Res> {
  _$FlightModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FlightModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flightNumber = null,
    Object? origin = null,
    Object? destination = null,
    Object? status = null,
    Object? scheduledDeparture = null,
    Object? estimatedDeparture = freezed,
    Object? gate = freezed,
    Object? terminal = freezed,
    Object? checkInCounter = freezed,
    Object? boardingTime = freezed,
  }) {
    return _then(_value.copyWith(
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledDeparture: null == scheduledDeparture
          ? _value.scheduledDeparture
          : scheduledDeparture // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedDeparture: freezed == estimatedDeparture
          ? _value.estimatedDeparture
          : estimatedDeparture // ignore: cast_nullable_to_non_nullable
              as String?,
      gate: freezed == gate
          ? _value.gate
          : gate // ignore: cast_nullable_to_non_nullable
              as String?,
      terminal: freezed == terminal
          ? _value.terminal
          : terminal // ignore: cast_nullable_to_non_nullable
              as String?,
      checkInCounter: freezed == checkInCounter
          ? _value.checkInCounter
          : checkInCounter // ignore: cast_nullable_to_non_nullable
              as String?,
      boardingTime: freezed == boardingTime
          ? _value.boardingTime
          : boardingTime // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FlightModelImplCopyWith<$Res>
    implements $FlightModelCopyWith<$Res> {
  factory _$$FlightModelImplCopyWith(
          _$FlightModelImpl value, $Res Function(_$FlightModelImpl) then) =
      __$$FlightModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String flightNumber,
      String origin,
      String destination,
      String status,
      String scheduledDeparture,
      String? estimatedDeparture,
      String? gate,
      String? terminal,
      String? checkInCounter,
      String? boardingTime});
}

/// @nodoc
class __$$FlightModelImplCopyWithImpl<$Res>
    extends _$FlightModelCopyWithImpl<$Res, _$FlightModelImpl>
    implements _$$FlightModelImplCopyWith<$Res> {
  __$$FlightModelImplCopyWithImpl(
      _$FlightModelImpl _value, $Res Function(_$FlightModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of FlightModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? flightNumber = null,
    Object? origin = null,
    Object? destination = null,
    Object? status = null,
    Object? scheduledDeparture = null,
    Object? estimatedDeparture = freezed,
    Object? gate = freezed,
    Object? terminal = freezed,
    Object? checkInCounter = freezed,
    Object? boardingTime = freezed,
  }) {
    return _then(_$FlightModelImpl(
      flightNumber: null == flightNumber
          ? _value.flightNumber
          : flightNumber // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as String,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledDeparture: null == scheduledDeparture
          ? _value.scheduledDeparture
          : scheduledDeparture // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedDeparture: freezed == estimatedDeparture
          ? _value.estimatedDeparture
          : estimatedDeparture // ignore: cast_nullable_to_non_nullable
              as String?,
      gate: freezed == gate
          ? _value.gate
          : gate // ignore: cast_nullable_to_non_nullable
              as String?,
      terminal: freezed == terminal
          ? _value.terminal
          : terminal // ignore: cast_nullable_to_non_nullable
              as String?,
      checkInCounter: freezed == checkInCounter
          ? _value.checkInCounter
          : checkInCounter // ignore: cast_nullable_to_non_nullable
              as String?,
      boardingTime: freezed == boardingTime
          ? _value.boardingTime
          : boardingTime // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FlightModelImpl extends _FlightModel {
  const _$FlightModelImpl(
      {required this.flightNumber,
      required this.origin,
      required this.destination,
      required this.status,
      required this.scheduledDeparture,
      this.estimatedDeparture,
      this.gate,
      this.terminal,
      this.checkInCounter,
      this.boardingTime})
      : super._();

  factory _$FlightModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$FlightModelImplFromJson(json);

  @override
  final String flightNumber;
  @override
  final String origin;
  @override
  final String destination;
  @override
  final String status;
  @override
  final String scheduledDeparture;
  @override
  final String? estimatedDeparture;
  @override
  final String? gate;
  @override
  final String? terminal;
  @override
  final String? checkInCounter;
  @override
  final String? boardingTime;

  @override
  String toString() {
    return 'FlightModel(flightNumber: $flightNumber, origin: $origin, destination: $destination, status: $status, scheduledDeparture: $scheduledDeparture, estimatedDeparture: $estimatedDeparture, gate: $gate, terminal: $terminal, checkInCounter: $checkInCounter, boardingTime: $boardingTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FlightModelImpl &&
            (identical(other.flightNumber, flightNumber) ||
                other.flightNumber == flightNumber) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.scheduledDeparture, scheduledDeparture) ||
                other.scheduledDeparture == scheduledDeparture) &&
            (identical(other.estimatedDeparture, estimatedDeparture) ||
                other.estimatedDeparture == estimatedDeparture) &&
            (identical(other.gate, gate) || other.gate == gate) &&
            (identical(other.terminal, terminal) ||
                other.terminal == terminal) &&
            (identical(other.checkInCounter, checkInCounter) ||
                other.checkInCounter == checkInCounter) &&
            (identical(other.boardingTime, boardingTime) ||
                other.boardingTime == boardingTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      flightNumber,
      origin,
      destination,
      status,
      scheduledDeparture,
      estimatedDeparture,
      gate,
      terminal,
      checkInCounter,
      boardingTime);

  /// Create a copy of FlightModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FlightModelImplCopyWith<_$FlightModelImpl> get copyWith =>
      __$$FlightModelImplCopyWithImpl<_$FlightModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FlightModelImplToJson(
      this,
    );
  }
}

abstract class _FlightModel extends FlightModel {
  const factory _FlightModel(
      {required final String flightNumber,
      required final String origin,
      required final String destination,
      required final String status,
      required final String scheduledDeparture,
      final String? estimatedDeparture,
      final String? gate,
      final String? terminal,
      final String? checkInCounter,
      final String? boardingTime}) = _$FlightModelImpl;
  const _FlightModel._() : super._();

  factory _FlightModel.fromJson(Map<String, dynamic> json) =
      _$FlightModelImpl.fromJson;

  @override
  String get flightNumber;
  @override
  String get origin;
  @override
  String get destination;
  @override
  String get status;
  @override
  String get scheduledDeparture;
  @override
  String? get estimatedDeparture;
  @override
  String? get gate;
  @override
  String? get terminal;
  @override
  String? get checkInCounter;
  @override
  String? get boardingTime;

  /// Create a copy of FlightModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FlightModelImplCopyWith<_$FlightModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
