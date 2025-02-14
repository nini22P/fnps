import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:collection/collection.dart';
import 'package:vita_dl/utils/content_info.dart';

List<Content> useContents(Content content, String? hmacKey) {
  if (content.type != ContentType.app) return [content];

  final titleID = useMemoized(() => content.titleID);
  final update = useState<Content?>(null);

  useEffect(() {
    () async {
      if (hmacKey != null && hmacKey.isNotEmpty) {
        final app = Hive.box<Content>(appBoxName)
            .values
            .toList()
            .firstWhereOrNull((content) => content.titleID == titleID);
        if (app != null) {
          update.value = await getUpdate(app, hmacKey);
        }
      }
    }();
    return null;
  }, []);

  return [
    ...Hive.box<Content>(appBoxName)
        .values
        .where((content) => content.titleID == titleID),
    if (update.value != null) update.value as Content,
    ...Hive.box<Content>(dlcBoxName)
        .values
        .where((content) => content.titleID == titleID),
    ...Hive.box<Content>(themeBoxName)
        .values
        .where((content) => content.titleID == titleID),
  ];
}
