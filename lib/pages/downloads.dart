import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/path_conv.dart';
import 'package:vita_dl/utils/pkg.dart';

class Downloads extends HookWidget {
  const Downloads({super.key});

  @override
  Widget build(BuildContext context) {
    final refreshValue = useState(false);
    refresh() => refreshValue.value = !refreshValue.value;

    final recordsFuture = useMemoized(
        () async => await FileDownloader().database.allRecords(),
        [refreshValue.value]);
    final records = useFuture(recordsFuture).data ?? [];

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(
            Content.fromJson(jsonDecode(records[index].task.metaData)).name),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await FileDownloader().cancelTaskWithId(records[index].taskId);
            await FileDownloader()
                .database
                .deleteRecordWithId(records[index].taskId);
            refresh();
          },
        ),
        onTap: () async {
          final List<String> path =
              pathConv(await records[index].task.filePath());
          final content =
              Content.fromJson(jsonDecode(records[index].task.metaData));
          final pkgName = await getPkgName(path);
          final result = await pkg2zip(
              path: path,
              extract: content.type == ContentType.theme ? false : true,
              zRIF: content.zRIF);
          print(result);
        },
      ),
    );
  }
}
