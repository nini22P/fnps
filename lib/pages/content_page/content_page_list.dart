import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/pages/content_list.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/utils/content_info.dart';

class ContentPageList extends HookWidget {
  const ContentPageList({super.key, required this.content});

  final Content content;

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    final config = configProvider.config;
    String? hmacKey = config.hmacKey;

    final dlcBox = useMemoized(() => Hive.box<Content>(dlcBoxName));
    final themeBox = useMemoized(() => Hive.box<Content>(themeBoxName));

    List<Content> getDLCs() => content.type != ContentType.app
        ? []
        : dlcBox.values
            .where((item) => content.titleID == item.titleID)
            .toList();

    List<Content> getThemes() => content.type != ContentType.app
        ? []
        : themeBox.values
            .where((item) => content.titleID == item.titleID)
            .toList();

    Future<Content?> getUpdate(String hmacKey) async =>
        content.type != ContentType.app || hmacKey.isEmpty
            ? null
            : await getUpdateLink(content, hmacKey);

    final updateFuture =
        useMemoized(() => hmacKey == null ? null : getUpdate(hmacKey));

    final update = useFuture(updateFuture).data;
    final dlcs = useMemoized(() => getDLCs());
    final themes = useMemoized(() => getThemes());

    return ContentList(
      contents: [
        content,
        if (update != null) update,
        if (dlcs.isNotEmpty) ...dlcs,
        if (themes.isNotEmpty) ...themes,
      ],
    );
  }
}
