import 'package:android_x_storage/android_x_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/downloader/downloader.dart';
import 'package:vita_dl/utils/file_size_convert.dart';

class Downloads extends HookWidget {
  const Downloads({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadBox = Hive.box<DownloadItem>(downloadBoxName);
    final downloads =
        useListenable(downloadBox.listenable()).value.values.toList();
    final downloader = Downloader.instance;

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
          onPressed: () => downloader.remove(downloads[index].content),
        ),
        onTap: () async {
          switch (downloads[index].downloadStatus) {
            case DownloadStatus.completed:
              return;
            case DownloadStatus.paused:
              await downloader.resume(downloads[index].content);
              return;
            default:
              await downloader.pause(downloads[index].content);
              break;
          }
          switch (downloads[index].extractStatus) {
            case ExtractStatus.failed:
              break;
            default:
              break;
          }
        },
      ),
    );
  }
}
