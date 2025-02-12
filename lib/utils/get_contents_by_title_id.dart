import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:collection/collection.dart';
import 'package:vita_dl/utils/content_info.dart';

Future<List<Content>> getContentsByTitleID(
  String titleID,
  String? hmacKey,
) async {
  Content? update;

  if (hmacKey != null && hmacKey.isNotEmpty) {
    final app = Hive.box<Content>(appBoxName)
        .values
        .toList()
        .firstWhereOrNull((content) => content.titleID == titleID);
    if (app != null) {
      update = await getUpdateLink(app, hmacKey);
    }
  }

  return [
    ...Hive.box<Content>(appBoxName)
        .values
        .where((content) => content.titleID == titleID),
    if (update != null) update,
    ...Hive.box<Content>(dlcBoxName)
        .values
        .where((content) => content.titleID == titleID),
    ...Hive.box<Content>(themeBoxName)
        .values
        .where((content) => content.titleID == titleID),
  ];
}
