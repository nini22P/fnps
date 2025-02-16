import 'package:fnps/utils/env.dart';
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
    required List<Source> sources,
    required List<Platform> platforms,
    required List<Category> categories,
    required List<Region> regions,
    String? hmacKey,
    @Default(SortBy.name) SortBy sortBy,
    @Default(SortOrder.asc) SortOrder sortOrder,
  }) = _Config;

  factory Config.fromJson(Map<String, dynamic> json) => _$ConfigFromJson(json);

  static final initConfig = Config(
    sources: [
      Source(
        platform: Platform.psv,
        category: Category.game,
        url: Env().psvGamesUrl,
      ),
      Source(
        platform: Platform.psv,
        category: Category.dlc,
        url: Env().psvDLCsUrl,
      ),
      Source(
        platform: Platform.psv,
        category: Category.theme,
        url: Env().psvThemesUrl,
      ),
      Source(
        platform: Platform.psv,
        category: Category.update,
        url: Env().psvUpdatesUrl,
      ),
      Source(
        platform: Platform.psv,
        category: Category.demo,
        url: Env().psvDemosUrl,
      ),
      Source(
        platform: Platform.psp,
        category: Category.game,
        url: Env().pspGamesUrl,
      ),
      Source(
        platform: Platform.psp,
        category: Category.dlc,
        url: Env().pspDLCsUrl,
      ),
      Source(
        platform: Platform.psp,
        category: Category.theme,
        url: Env().pspThemesUrl,
      ),
      Source(
        platform: Platform.psp,
        category: Category.update,
        url: Env().pspUpdatesUrl,
      ),
      Source(
        platform: Platform.psm,
        category: Category.game,
        url: Env().psmGamesUrl,
      ),
      Source(
        platform: Platform.psx,
        category: Category.game,
        url: Env().psxGamesUrl,
      ),
      Source(
        platform: Platform.ps3,
        category: Category.game,
        url: Env().ps3GamesUrl,
      ),
      Source(
        platform: Platform.ps3,
        category: Category.dlc,
        url: Env().ps3DLCsUrl,
      ),
      Source(
        platform: Platform.ps3,
        category: Category.theme,
        url: Env().ps3ThemesUrl,
      ),
      Source(
        platform: Platform.ps3,
        category: Category.demo,
        url: Env().ps3DemosUrl,
      ),
    ],
    platforms: [Platform.psv, Platform.psp],
    categories: [Category.game, Category.dlc, Category.theme, Category.demo],
    regions: Region.values,
    hmacKey: Env().hmacKey,
    sortBy: SortBy.name,
    sortOrder: SortOrder.asc,
  );
}

@freezed
class Source with _$Source {
  const factory Source({
    required Platform platform,
    required Category category,
    DateTime? updateTime,
    String? url,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
