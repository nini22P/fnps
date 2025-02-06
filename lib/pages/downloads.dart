import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/utils/downloader.dart';
import 'package:vita_dl/utils/file_size_convert.dart';
import 'package:vita_dl/utils/pkg.dart';

class Downloads extends HookWidget {
  const Downloads({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadBox = Hive.box<DownloadItem>(downloadBoxName);
    final downloads =
        useListenable(downloadBox.listenable()).value.values.toList();
    final downloader = Downloader.instance;
    final fileDownloader = downloader.fileDownloader;

    return ListView.builder(
      itemCount: downloads.length,
      itemBuilder: (context, index) => ListTile(
        leading: Text(
            '${(downloads[index].progress * 100).toStringAsFixed(downloads[index].progress < 1 ? 2 : 0)}%'),
        title: Text(downloads[index].content.name),
        subtitle: Text(
            '${fileSizeConvert((downloads[index].content.fileSize! * downloads[index].progress).toInt())}MB / ${fileSizeConvert(downloads[index].content.fileSize ?? 0)}MB  ${downloads[index].downloadStatus} ${downloads[index].extractStatus}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => downloader.removeFromQueue(downloads[index].content),
        ),
        onTap: () async {
          // final taskId = downloads[index].key;
          // final record = await fileDownloader.database.recordForId(taskId);
          // print(record);
          switch (downloads[index].downloadStatus) {
            case DownloadStatus.complete:
              return;
            case DownloadStatus.paused:
              final result = await downloader.resume(downloads[index].content);
              if (!result && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Not resumable'),
                  action: SnackBarAction(
                    label: 'Restart download',
                    onPressed: () {
                      log('Restart pressed');
                    },
                  ),
                ));
              }
              break;
            default:
              await downloader.pause(downloads[index].content);
              break;
          }
          switch (downloads[index].extractStatus) {
            case ExtractStatus.failed:
              await extractPkg(downloads[index].content);
              break;
            default:
              break;
          }
        },
      ),
    );
  }
}
