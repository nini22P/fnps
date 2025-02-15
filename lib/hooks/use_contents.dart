import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/utils/content_info.dart';

List<Content> useContents(Content content, String? hmacKey) {
  if (content.category != Category.game) return [content];

  final psvBox = Hive.box<Content>(psvBoxName);
  final pspBox = Hive.box<Content>(pspBoxName);
  final psmBox = Hive.box<Content>(psmBoxName);
  final psxBox = Hive.box<Content>(psxBoxName);

  final contents = useMemoized(() => [
        ...psvBox.values,
        ...pspBox.values,
        ...psmBox.values,
        ...psxBox.values,
      ]);

  final titleID = useMemoized(() => content.titleID);
  // final List<Content> updates = useMemoized(() => contents
  //     .where((content) =>
  //         content.titleID == titleID && content.category == Category.update)
  //     .toList());
  // final List<Content> sortedUpdates =
  //     [...updates].sorted((a, b) => b.appVersion!.compareTo(a.appVersion!));
  // final Content? latestUpdate =
  //     sortedUpdates.isEmpty ? null : sortedUpdates.first;
  final update = useState<Content?>(null);

  useEffect(() {
    () async {
      if (hmacKey != null && hmacKey.isNotEmpty) {
        update.value = await getUpdate(content, hmacKey) ?? update.value;
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
