import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/pages/content_list.dart';

class Downloads extends HookWidget {
  const Downloads({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadBox = Hive.box<DownloadItem>(downloadBoxName);
    final downloads =
        useListenable(downloadBox.listenable()).value.values.toList();

    final contents = useMemoized(
        () => downloads.map((item) => item.content).toList(), [downloads]);

    return ContentList(contents: contents);
  }
}
