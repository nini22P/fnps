import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:vita_dl/hive/hive_types.dart';

part 'content.freezed.dart';
part 'content.g.dart';

@HiveType(typeId: contentTypeTypeId)
enum ContentType {
  @HiveField(0)
  app,
  @HiveField(1)
  update,
  @HiveField(2)
  dlc,
  @HiveField(3)
  theme,
}

@freezed
@HiveType(typeId: contentTypeId)
abstract class Content extends HiveObject with _$Content {
  Content._();

  factory Content({
    @HiveField(0) required ContentType type,
    @HiveField(1) required String titleID,
    @HiveField(2) required String name,
    @HiveField(3) String? region,
    @HiveField(4) String? pkgDirectLink,
    @HiveField(5) String? zRIF,
    @HiveField(6) String? contentID,
    @HiveField(7) String? lastModificationDate,
    @HiveField(8) String? originalName,
    @HiveField(9) int? fileSize,
    @HiveField(10) String? sha256,
    @HiveField(11) String? requiredFW,
    @HiveField(12) String? appVersion,
  }) = _Content;

  factory Content.fromJson(Map<String, dynamic> json) =>
      _$ContentFromJson(json);

  factory Content.convert(Map<String, dynamic> map) {
    String? checkNull(String? text) =>
        (text == null || text == 'MISSING' || text.isEmpty) ? null : text;
    return Content(
      type: map['Type'],
      titleID: map['Title ID'],
      region: map['Region'],
      name: map['Name'],
      pkgDirectLink: checkNull(map['PKG direct link']),
      zRIF: checkNull(map['zRIF']),
      contentID: checkNull(map['Content ID']),
      lastModificationDate: checkNull(map['Last Modification Date']),
      originalName: checkNull(map['Original Name']),
      fileSize: int.tryParse(map['File Size']),
      sha256: checkNull(map['SHA256']),
      requiredFW: checkNull(map['Required FW']),
      appVersion: checkNull(map['App Version']),
    );
  }
}
