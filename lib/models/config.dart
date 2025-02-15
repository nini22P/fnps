import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fnps/models/content.dart';

part 'config.freezed.dart';
part 'config.g.dart';

enum SortBy {
  name,
  titleID,
  lastModificationDate,
}

enum SortOrder {
  asc,
  desc,
}

@freezed
class Config with _$Config {
  const factory Config({
    required Source psvGames,
    required Source psvDLCs,
    required Source psvThemes,
    required Source psvDEMOs,
    required Source pspGames,
    required Source pspDLCs,
    required List<Platform> platforms,
    required List<Category> categories,
    required List<String> regions,
    String? hmacKey,
    @Default(SortBy.name) SortBy sortBy,
    @Default(SortOrder.asc) SortOrder sortOrder,
  }) = _Config;

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

  static final initConfig = Config(
    psvGames: const Source(type: SourceType.local),
    psvDLCs: const Source(type: SourceType.local),
    psvThemes: const Source(type: SourceType.local),
    psvDEMOs: const Source(type: SourceType.local),
    pspGames: const Source(type: SourceType.local),
    pspDLCs: const Source(type: SourceType.local),
    platforms: [Platform.psv, Platform.psp],
    categories: [Category.game, Category.dlc, Category.theme, Category.demo],
    regions: ['JP', 'ASIA', 'US', 'EU', 'INT', 'UNKNOWN'],
    hmacKey: dotenv.env['HMAC_KEY'],
    sortBy: SortBy.name,
    sortOrder: SortOrder.asc,
  );
}

enum SourceType { remote, local }

@freezed
class Source with _$Source {
  const factory Source({
    required SourceType type,
    DateTime? updateTime,
    String? url,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
