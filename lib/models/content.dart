import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:fnps/hive/hive_types.dart';

part 'content.freezed.dart';
part 'content.g.dart';

@HiveType(typeId: platformTypeId)
enum Platform {
  @HiveField(0)
  psv,
  @HiveField(1)
  psp,
  @HiveField(2)
  ps3,
  @HiveField(3)
  psx,
  @HiveField(4)
  psm,
  @HiveField(5)
  go,
  @HiveField(6)
  minis,
  @HiveField(7)
  neoGeo,
  @HiveField(8)
  pcEngine,
}

@HiveType(typeId: categoryTypeId)
enum Category {
  @HiveField(0)
  game,
  @HiveField(1)
  dlc,
  @HiveField(2)
  theme,
  @HiveField(3)
  update,
  @HiveField(4)
  demo,
}

@HiveType(typeId: regionTypeId)
enum Region {
  @HiveField(0)
  asia,
  @HiveField(1)
  jp,
  @HiveField(2)
  us,
  @HiveField(3)
  eu,
  @HiveField(4)
  int,
  @HiveField(5)
  unknown,
}

@freezed
@HiveType(typeId: contentTypeId)
abstract class Content extends HiveObject with _$Content {
  Content._();

  factory Content({
    @HiveField(0) required Platform platform,
    @HiveField(1) required Category category,
    @HiveField(2) required String titleID,
    @HiveField(3) required String name,
    @HiveField(4) Region? region,
    @HiveField(5) String? pkgDirectLink,
    @HiveField(6) String? zRIF,
    @HiveField(7) String? rap,
    @HiveField(8) String? contentID,
    @HiveField(9) String? lastModificationDate,
    @HiveField(10) String? originalName,
    @HiveField(11) int? fileSize,
    @HiveField(12) String? sha256,
    @HiveField(13) String? sha1sum,
    @HiveField(14) String? requiredFW,
    @HiveField(15) String? appVersion,
  }) = _Content;

  factory Content.fromJson(Map<String, dynamic> json) =>
      _$ContentFromJson(json);

  factory Content.convert(
      Map<String, dynamic> map, Platform platform, Category category) {
    String? checkNull(String? text) =>
        (text == null || text == 'MISSING' || text.isEmpty) ? null : text;

    Platform checkPlatform(String? text) {
      if (platform == Platform.psp) {
        if (text?.contains('Go') ?? false) return Platform.go;
        if (text?.contains('Minis') ?? false) return Platform.minis;
        if (text?.contains('NeoGeo') ?? false) return Platform.neoGeo;
        if (text?.contains('PC Engine') ?? false) return Platform.pcEngine;
        return platform;
      } else {
        return platform;
      }
    }

    Region checkRegion(String? text) {
      if (text == 'ASIA') return Region.asia;
      if (text == 'JP') return Region.jp;
      if (text == 'US') return Region.us;
      if (text == 'EU') return Region.eu;
      if (text == 'INT') return Region.int;
      return Region.unknown;
    }

    return Content(
      platform: checkPlatform(map['Type']),
      category: category,
      titleID: map['Title ID'],
      region: checkRegion(map['Region']),
      name: map['Name'],
      pkgDirectLink: checkNull(map['PKG direct link']),
      zRIF: checkNull(map['zRIF']),
      rap: checkNull(map['RAP']),
      contentID: checkNull(map['Content ID']),
      lastModificationDate: checkNull(map['Last Modification Date']),
      originalName: checkNull(map['Original Name']),
      fileSize: int.tryParse(map['File Size']),
      sha256: checkNull(map['SHA256']),
      requiredFW: checkNull(map['Required FW']),
      appVersion: checkNull(map['App Version']),
    );
  }

  String? getID() => category == Category.update && contentID != null
      ? '$contentID-$appVersion'
      : contentID;
}
