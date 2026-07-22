// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'airport_info_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AirportInfoModel _$AirportInfoModelFromJson(Map<String, dynamic> json) {
  return _AirportInfoModel.fromJson(json);
}

/// @nodoc
mixin _$AirportInfoModel {
  String get terminal => throw _privateConstructorUsedError;
  String get checkInCounter => throw _privateConstructorUsedError;
  String get gate => throw _privateConstructorUsedError;
  int get walkingTimeMinutes => throw _privateConstructorUsedError;
  String? get indoorMapAssetPath => throw _privateConstructorUsedError;
  List<String> get directions => throw _privateConstructorUsedError;

  /// Serializes this AirportInfoModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AirportInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AirportInfoModelCopyWith<AirportInfoModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AirportInfoModelCopyWith<$Res> {
  factory $AirportInfoModelCopyWith(
          AirportInfoModel value, $Res Function(AirportInfoModel) then) =
      _$AirportInfoModelCopyWithImpl<$Res, AirportInfoModel>;
  @useResult
  $Res call(
      {String terminal,
      String checkInCounter,
      String gate,
      int walkingTimeMinutes,
      String? indoorMapAssetPath,
      List<String> directions});
}

/// @nodoc
class _$AirportInfoModelCopyWithImpl<$Res, $Val extends AirportInfoModel>
    implements $AirportInfoModelCopyWith<$Res> {
  _$AirportInfoModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AirportInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? terminal = null,
    Object? checkInCounter = null,
    Object? gate = null,
    Object? walkingTimeMinutes = null,
    Object? indoorMapAssetPath = freezed,
    Object? directions = null,
  }) {
    return _then(_value.copyWith(
      terminal: null == terminal
          ? _value.terminal
          : terminal // ignore: cast_nullable_to_non_nullable
              as String,
      checkInCounter: null == checkInCounter
          ? _value.checkInCounter
          : checkInCounter // ignore: cast_nullable_to_non_nullable
              as String,
      gate: null == gate
          ? _value.gate
          : gate // ignore: cast_nullable_to_non_nullable
              as String,
      walkingTimeMinutes: null == walkingTimeMinutes
          ? _value.walkingTimeMinutes
          : walkingTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      indoorMapAssetPath: freezed == indoorMapAssetPath
          ? _value.indoorMapAssetPath
          : indoorMapAssetPath // ignore: cast_nullable_to_non_nullable
              as String?,
      directions: null == directions
          ? _value.directions
          : directions // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AirportInfoModelImplCopyWith<$Res>
    implements $AirportInfoModelCopyWith<$Res> {
  factory _$$AirportInfoModelImplCopyWith(_$AirportInfoModelImpl value,
          $Res Function(_$AirportInfoModelImpl) then) =
      __$$AirportInfoModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String terminal,
      String checkInCounter,
      String gate,
      int walkingTimeMinutes,
      String? indoorMapAssetPath,
      List<String> directions});
}

/// @nodoc
class __$$AirportInfoModelImplCopyWithImpl<$Res>
    extends _$AirportInfoModelCopyWithImpl<$Res, _$AirportInfoModelImpl>
    implements _$$AirportInfoModelImplCopyWith<$Res> {
  __$$AirportInfoModelImplCopyWithImpl(_$AirportInfoModelImpl _value,
      $Res Function(_$AirportInfoModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of AirportInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? terminal = null,
    Object? checkInCounter = null,
    Object? gate = null,
    Object? walkingTimeMinutes = null,
    Object? indoorMapAssetPath = freezed,
    Object? directions = null,
  }) {
    return _then(_$AirportInfoModelImpl(
      terminal: null == terminal
          ? _value.terminal
          : terminal // ignore: cast_nullable_to_non_nullable
              as String,
      checkInCounter: null == checkInCounter
          ? _value.checkInCounter
          : checkInCounter // ignore: cast_nullable_to_non_nullable
              as String,
      gate: null == gate
          ? _value.gate
          : gate // ignore: cast_nullable_to_non_nullable
              as String,
      walkingTimeMinutes: null == walkingTimeMinutes
          ? _value.walkingTimeMinutes
          : walkingTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      indoorMapAssetPath: freezed == indoorMapAssetPath
          ? _value.indoorMapAssetPath
          : indoorMapAssetPath // ignore: cast_nullable_to_non_nullable
              as String?,
      directions: null == directions
          ? _value._directions
          : directions // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AirportInfoModelImpl extends _AirportInfoModel {
  const _$AirportInfoModelImpl(
      {required this.terminal,
      required this.checkInCounter,
      required this.gate,
      required this.walkingTimeMinutes,
      this.indoorMapAssetPath,
      final List<String> directions = const <String>[]})
      : _directions = directions,
        super._();

  factory _$AirportInfoModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$AirportInfoModelImplFromJson(json);

  @override
  final String terminal;
  @override
  final String checkInCounter;
  @override
  final String gate;
  @override
  final int walkingTimeMinutes;
  @override
  final String? indoorMapAssetPath;
  final List<String> _directions;
  @override
  @JsonKey()
  List<String> get directions {
    if (_directions is EqualUnmodifiableListView) return _directions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_directions);
  }

  @override
  String toString() {
    return 'AirportInfoModel(terminal: $terminal, checkInCounter: $checkInCounter, gate: $gate, walkingTimeMinutes: $walkingTimeMinutes, indoorMapAssetPath: $indoorMapAssetPath, directions: $directions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AirportInfoModelImpl &&
            (identical(other.terminal, terminal) ||
                other.terminal == terminal) &&
            (identical(other.checkInCounter, checkInCounter) ||
                other.checkInCounter == checkInCounter) &&
            (identical(other.gate, gate) || other.gate == gate) &&
            (identical(other.walkingTimeMinutes, walkingTimeMinutes) ||
                other.walkingTimeMinutes == walkingTimeMinutes) &&
            (identical(other.indoorMapAssetPath, indoorMapAssetPath) ||
                other.indoorMapAssetPath == indoorMapAssetPath) &&
            const DeepCollectionEquality()
                .equals(other._directions, _directions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      terminal,
      checkInCounter,
      gate,
      walkingTimeMinutes,
      indoorMapAssetPath,
      const DeepCollectionEquality().hash(_directions));

  /// Create a copy of AirportInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AirportInfoModelImplCopyWith<_$AirportInfoModelImpl> get copyWith =>
      __$$AirportInfoModelImplCopyWithImpl<_$AirportInfoModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AirportInfoModelImplToJson(
      this,
    );
  }
}

abstract class _AirportInfoModel extends AirportInfoModel {
  const factory _AirportInfoModel(
      {required final String terminal,
      required final String checkInCounter,
      required final String gate,
      required final int walkingTimeMinutes,
      final String? indoorMapAssetPath,
      final List<String> directions}) = _$AirportInfoModelImpl;
  const _AirportInfoModel._() : super._();

  factory _AirportInfoModel.fromJson(Map<String, dynamic> json) =
      _$AirportInfoModelImpl.fromJson;

  @override
  String get terminal;
  @override
  String get checkInCounter;
  @override
  String get gate;
  @override
  int get walkingTimeMinutes;
  @override
  String? get indoorMapAssetPath;
  @override
  List<String> get directions;

  /// Create a copy of AirportInfoModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AirportInfoModelImplCopyWith<_$AirportInfoModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
