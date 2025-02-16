import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/open_explorer.dart';
import 'package:fnps/widgets/custom_badge.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:fnps/downloader/downloader.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/pages/content_page/content_page.dart';
import 'package:fnps/utils/file_size_convert.dart';
import 'package:fnps/utils/get_localizations.dart';

class Downloads extends HookWidget {
  const Downloads({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final downloader = useMemoized(() => Downloader.instance);

    final psvBox = Hive.box<Content>(psvBoxName);
    final pspBox = Hive.box<Content>(pspBoxName);
    final psmBox = Hive.box<Content>(psmBoxName);
    final psxBox = Hive.box<Content>(psxBoxName);
    final ps3Box = Hive.box<Content>(ps3BoxName);
    final downloadBox = Hive.box<DownloadItem>(downloadBoxName);

    final downloads =
        useListenable(downloadBox.listenable()).value.values.toList();

    final apps = useMemoized(
        () => [
              ...psvBox.values,
              ...pspBox.values,
              ...psmBox.values,
              ...psxBox.values,
              ...ps3Box.values
            ]
                .where((content) => downloads.any((download) =>
                    (download.content == content &&
                        content.category == Category.game) ||
                    (download.content.category != Category.game &&
                        download.content.titleID == content.titleID &&
                        content.category == Category.game)))
                .toList(),
        [downloads]);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.download),
        forceMaterialTransparency: true,
      ),
      body: ListView.builder(
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final content = apps[index];

          final currentDownloads = downloads
              .where((item) => item.content.titleID == content.titleID)
              .toList();

          final contents =
              currentDownloads.map((item) => item.content).toList();

          final currentCompletedDownloads = currentDownloads
              .where((item) => item.extractStatus == ExtractStatus.completed);

          bool isDownloading = currentDownloads
              .any((item) => item.downloadStatus == DownloadStatus.downloading);

          bool isExtracting = currentDownloads
              .any((item) => item.extractStatus == ExtractStatus.extracting);

          final incompletedDownloads = currentDownloads
              .where((item) => item.downloadStatus != DownloadStatus.completed)
              .toList();

          final allDownloadSize = currentDownloads
              .map((item) => item.size)
              .reduce((value, element) => value + element);

          final currentDownloadSize = currentDownloads
              .map((item) => item.size * item.progress)
              .reduce((value, element) => value + element)
              .toInt();

          return ListTile(
            title: Text(content.name),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 4),
                CustomBadge(
                    text: incompletedDownloads.isEmpty
                        ? '${fileSizeConv(currentDownloadSize)}'
                        : '${fileSizeConv(currentDownloadSize)} / ${fileSizeConv(allDownloadSize)}'),
                const SizedBox(width: 4),
                CustomBadge(
                    text: currentCompletedDownloads.length ==
                            currentDownloads.length
                        ? '${currentCompletedDownloads.length}'
                        : '${currentCompletedDownloads.length} / ${currentDownloads.length}'),
                if (isExtracting && incompletedDownloads.isEmpty)
                  const SizedBox(width: 4),
                if (isExtracting && incompletedDownloads.isEmpty)
                  CustomBadge(text: t.extracting),
              ],
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (incompletedDownloads.isNotEmpty)
                isDownloading
                    ? IconButton(
                        tooltip: isExtracting ? t.extracting : t.pause,
                        icon: const Icon(Icons.pause),
                        onPressed: () => downloader.pause(contents))
                    : IconButton(
                        tooltip: t.download,
                        icon: const Icon(Icons.download),
                        onPressed: () => downloader.add(incompletedDownloads
                            .map((e) => e.content)
                            .toList())),
              IconButton(
                tooltip: t.open_in_folder,
                icon: const Icon(Icons.folder_open),
                onPressed: () async {
                  final result =
                      await openExplorer(dir: currentDownloads[0].directory);
                  if (!result && context.mounted) {
                    logger('Could not open directory');
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t.cannot_open_in_folder)));
                  }
                },
              ),
              IconButton(
                  tooltip: t.delete,
                  icon: const Icon(Icons.delete),
                  onPressed: () => downloader.remove(contents)),
            ]),
            onTap: () {
              Navigator.pushNamed(context, '/content',
                  arguments:
                      ContentPageProps(content: content, initialIndex: 1));
            },
          );
        },
      ),
    );
  }
}
