import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/content_info.dart';

List<Content> useContents(Content content, String? hmacKey) {
  if (content.category != Category.game) return [content];

  final psvBox = useMemoized(() => Hive.box<Content>(psvBoxName));
  final pspBox = useMemoized(() => Hive.box<Content>(pspBoxName));

  final contents = useMemoized(() => [...psvBox.values, ...pspBox.values]);

  final titleID = useMemoized(() => content.titleID);
  final update = useState<Content?>(null);

  useEffect(() {
    () async {
      if (hmacKey != null && hmacKey.isNotEmpty) {
        update.value = await getUpdate(content, hmacKey);
      }
    }();
    return null;
  }, []);

  return [
    content,
    if (update.value != null) update.value as Content,
    ...contents.where((content) =>
        content.titleID == titleID && content.category == Category.dlc),
    ...contents.where((content) =>
        content.titleID == titleID && content.category == Category.theme),
  ];
}
