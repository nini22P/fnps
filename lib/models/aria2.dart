// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'aria2.freezed.dart';
part 'aria2.g.dart';

class Aria2Config {
  final int port;
  final String secret;
  Aria2Config({required this.port, required this.secret});
}

@freezed
abstract class Aria2GlobalStat with _$Aria2GlobalStat {
  const factory Aria2GlobalStat({
    @JsonKey(fromJson: _toInt) required int downloadSpeed,
    @JsonKey(fromJson: _toInt) required int uploadSpeed,
    @JsonKey(fromJson: _toInt) required int numActive,
    @JsonKey(fromJson: _toInt) required int numWaiting,
    @JsonKey(fromJson: _toInt) required int numStopped,
    @JsonKey(fromJson: _toInt) required int numStoppedTotal,
  }) = _Aria2GlobalStat;

  factory Aria2GlobalStat.fromJson(Map<String, dynamic> json) =>
      _$Aria2GlobalStatFromJson(json);
}

@freezed
abstract class Aria2Status with _$Aria2Status {
  const factory Aria2Status({
    required String gid,
    required String status,
    @JsonKey(fromJson: _toInt) required int totalLength,
    @JsonKey(fromJson: _toInt) required int completedLength,
    @JsonKey(fromJson: _toInt) required int downloadSpeed,
    @JsonKey(fromJson: _toInt) required int uploadSpeed,
    @JsonKey(fromJson: _toInt) required int pieceLength,
    @JsonKey(fromJson: _toInt) required int numPieces,
    @JsonKey(fromJson: _toInt) required int connections,
    String? dir,
    String? bitfield,
    required List<Aria2File> files,
  }) = _Aria2Status;

  factory Aria2Status.fromJson(Map<String, dynamic> json) =>
      _$Aria2StatusFromJson(json);
}

@freezed
abstract class Aria2File with _$Aria2File {
  const factory Aria2File({
    @JsonKey(fromJson: _toInt) required int index,
    @JsonKey(fromJson: _toInt) required int length,
    @JsonKey(fromJson: _toInt) required int completedLength,
    required String path,
    @JsonKey(fromJson: _toBool) required bool selected,
    required List<Aria2Uri> uris,
  }) = _Aria2File;

  factory Aria2File.fromJson(Map<String, dynamic> json) =>
      _$Aria2FileFromJson(json);
}

@freezed
abstract class Aria2Uri with _$Aria2Uri {
  const factory Aria2Uri({required String uri, required String status}) =
      _Aria2Uri;

  factory Aria2Uri.fromJson(Map<String, dynamic> json) =>
      _$Aria2UriFromJson(json);
}

int _toInt(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

bool _toBool(dynamic value) {
  if (value is bool) return value;
  return value.toString().toLowerCase() == 'true';
}
