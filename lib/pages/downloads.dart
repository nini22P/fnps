import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/utils/content_info.dart';
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

          final currentCompletedDownloads = currentDownloads.where((item) => [
                ExtractStatus.completed,
                ExtractStatus.notNeeded
              ].contains(item.extractStatus));

          bool isDownloading = currentDownloads
              .any((item) => item.downloadStatus == DownloadStatus.downloading);

          bool isExtracting = currentDownloads
              .any((item) => item.extractStatus == ExtractStatus.extracting);

          final incompletedDownloads = currentDownloads
              .where((item) => [ExtractStatus.queued, ExtractStatus.extracting]
                  .contains(item.extractStatus))
              .toList();

          final allDownloadSize = currentDownloads
              .map((item) => item.size)
              .reduce((value, element) => value + element);

          final currentDownloadSize = currentDownloads
              .map((item) => item.size * item.progress)
              .reduce((value, element) => value + element)
              .toInt();

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: getContentIcon(content, size: 96) ?? '',
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    child: Center(child: Icon(Icons.gamepad)),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.gamepad),
                  errorListener: (_) {},
                ),
              ),
            ),
            title: Text(content.name),
            subtitle: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                CustomBadge(text: content.platform.name),
                CustomBadge(text: content.titleID),
                CustomBadge(
                    text: incompletedDownloads.isEmpty
                        ? '${fileSizeConv(currentDownloadSize)}'
                        : '${fileSizeConv(currentDownloadSize)} / ${fileSizeConv(allDownloadSize)}'),
                CustomBadge(
                    text: currentCompletedDownloads.length ==
                            currentDownloads.length
                        ? '${currentCompletedDownloads.length}'
                        : '${currentCompletedDownloads.length} / ${currentDownloads.length}'),
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
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Text(t.open_in_folder),
                    onTap: () async {
                      final result = await openExplorer(
                          dir: currentDownloads[0].directory);
                      if (!result && context.mounted) {
                        logger('Could not open directory');
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.cannot_open_in_folder)));
                      }
                    },
                  ),
                  PopupMenuItem(
                    child: Text(t.delete),
                    onTap: () => downloader.remove([content]),
                  ),
                ],
              ),
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
