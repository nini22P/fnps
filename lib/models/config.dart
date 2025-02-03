import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@freezed
class Config with _$Config {
  const factory Config({
    required Source app,
    required Source dlc,
    required Source theme,
    required String? hmacKey,
    required List<String> regions,
  }) = _Config;

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

  static final initConfig = Config(
    app: const Source(type: SourceType.local, updateTime: null, url: null),
    dlc: const Source(type: SourceType.local, updateTime: null, url: null),
    theme: const Source(type: SourceType.local, updateTime: null, url: null),
    hmacKey: dotenv.env['HMAC_KEY'],
    regions: ['JP', 'US', 'INT', 'EU', 'ASIA', 'UNKNOWN'],
  );
}

enum SourceType { remote, local }

@freezed
class Source with _$Source {
  const factory Source({
    required SourceType type,
    required DateTime? updateTime,
    required String? url,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
