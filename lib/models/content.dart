import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'content.freezed.dart';
part 'content.g.dart';

enum ContentType {
  app,
  update,
  dlc,
  theme,
}

@freezed
abstract class Content with _$Content {
  const Content._();
  const factory Content({
    int? id,
    required ContentType type,
    required String titleID,
    required String name,
    String? region,
    String? pkgDirectLink,
    String? zRIF,
    String? contentID,
    String? lastModificationDate,
    String? originalName,
    int? fileSize,
    String? sha256,
    String? requiredFW,
    String? appVersion,
  }) = _Content;

  factory Content.fromJson(Map<String, dynamic> json) =>
      _$ContentFromJson(json);

  factory Content.convert(Map<String, dynamic> map) {
    String? checkNull(String? text) =>
        (text == null || text == 'MISSING' || text.isEmpty) ? null : text;
    return Content(
      id: map['ID'],
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
