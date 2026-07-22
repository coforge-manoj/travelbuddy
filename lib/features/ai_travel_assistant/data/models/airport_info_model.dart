import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/airport_info.dart';

part 'airport_info_model.freezed.dart';
part 'airport_info_model.g.dart';

@freezed
class AirportInfoModel with _$AirportInfoModel {
  const AirportInfoModel._();

  const factory AirportInfoModel({
    required String terminal,
    required String checkInCounter,
    required String gate,
    required int walkingTimeMinutes,
    String? indoorMapAssetPath,
    @Default(<String>[]) List<String> directions,
  }) = _AirportInfoModel;

  factory AirportInfoModel.fromJson(Map<String, dynamic> json) =>
      _$AirportInfoModelFromJson(json);

  AirportInfo toEntity() {
    return AirportInfo(
      terminal: terminal,
      checkInCounter: checkInCounter,
      gate: gate,
      walkingTimeMinutes: walkingTimeMinutes,
      indoorMapAssetPath: indoorMapAssetPath,
      directions: directions,
    );
  }
}
