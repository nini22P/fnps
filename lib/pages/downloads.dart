import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/downloader/downloader.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/pages/content_page/content_page.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/content_info.dart';
import 'package:fnps/utils/file_size_convert.dart';
import 'package:fnps/utils/get_localizations.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/open_explorer.dart';
import 'package:fnps/widgets/custom_badge.dart';
import 'package:fnps/widgets/downloads_clear_menu.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

class Downloads extends HookWidget {
  const Downloads({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final downloader = useMemoized(() => Downloader.instance);

    final pkg2zipOutputMode = context.select<ConfigProvider, Pkg2zipOutputMode>(
      (provider) => provider.config.pkg2zipOutputMode,
    );
    final bool isFolder = pkg2zipOutputMode == Pkg2zipOutputMode.folder;

    final psvBox = Hive.box<Content>(psvBoxName);
    final pspBox = Hive.box<Content>(pspBoxName);
    final psmBox = Hive.box<Content>(psmBoxName);
    final psxBox = Hive.box<Content>(psxBoxName);
    final ps3Box = Hive.box<Content>(ps3BoxName);
    final downloadBox = Hive.box<DownloadItem>(downloadBoxName);

    final downloads = useListenable(
      downloadBox.listenable(),
    ).value.values.toList();

    final apps = useMemoized(
      () =>
          [
                ...psvBox.values,
                ...pspBox.values,
                ...psmBox.values,
                ...psxBox.values,
                ...ps3Box.values,
              ]
              .where(
                (content) => downloads.any(
                  (download) =>
                      (download.content == content &&
                          content.category == Category.game) ||
                      (download.content.category != Category.game &&
                          download.content.titleID == content.titleID &&
                          content.category == Category.game),
                ),
              )
              .toList(),
      [downloads],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.download),
        forceMaterialTransparency: true,
        actions: [
          DownloadsClearMenu(downloadItems: downloads),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView.builder(
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final Content content = apps[index];

          final List<DownloadItem> currentDownloads = downloads
              .where((item) => item.content.titleID == content.titleID)
              .toList();

          int completedCount = 0;
          int allDownloadLength = 0;
          int completedDownloadLength = 0;
          bool isDownloading = false;
          bool isQueued = false;
          bool isExtracting = false;
          bool hasFailed = false;
          final List<Content> incompletedContents = <Content>[];
          final List<Content> allContents = <Content>[];

          for (final DownloadItem item in currentDownloads) {
            allContents.add(item.content);
            allDownloadLength += item.totalLength;
            completedDownloadLength += item.completedLength;

            final bool itemDone =
                item.extractStatus == ExtractStatus.completed ||
                item.extractStatus == ExtractStatus.notNeeded;
            if (itemDone) {
              completedCount++;
            } else {
              incompletedContents.add(item.content);
            }

            if (item.downloadStatus == DownloadStatus.downloading) {
              isDownloading = true;
            } else if (item.downloadStatus == DownloadStatus.queued) {
              isQueued = true;
            } else if (item.downloadStatus == DownloadStatus.failed) {
              hasFailed = true;
            } else if (item.downloadStatus == DownloadStatus.completed) {
              if (item.extractStatus == ExtractStatus.extracting) {
                isExtracting = true;
              } else if (item.extractStatus == ExtractStatus.failed) {
                hasFailed = true;
              }
            }
          }

          final String downloadPercent = allDownloadLength > 0
              ? (completedDownloadLength / allDownloadLength * 100)
                    .clamp(0.0, 100.0)
                    .toStringAsFixed(1)
              : '0.0';

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: getContentIcon(content, size: 96) ?? '',
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                    child: Center(child: Icon(Icons.gamepad_rounded)),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.gamepad_rounded),
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
                  text: incompletedContents.isEmpty
                      ? '${fileSizeConv(completedDownloadLength)}'
                      : '${fileSizeConv(completedDownloadLength)} / ${fileSizeConv(allDownloadLength)}',
                ),
                CustomBadge(
                  text: completedCount == currentDownloads.length
                      ? '$completedCount'
                      : '$completedCount / ${currentDownloads.length}',
                ),
                if (isDownloading)
                  CustomBadge(text: '${t.downloading} $downloadPercent%'),
                if (isExtracting)
                  CustomBadge(text: isFolder ? t.extracting : t.converting),
                if (!isDownloading && !isExtracting && isQueued)
                  CustomBadge(text: t.download_queued),
                if (!isDownloading && !isExtracting && !isQueued && hasFailed)
                  CustomBadge(text: t.download_failed),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (incompletedContents.isNotEmpty)
                  isDownloading
                      ? IconButton(
                          tooltip: t.pause,
                          icon: const Icon(Icons.pause_rounded),
                          onPressed: () => downloader.pause(allContents),
                        )
                      : IconButton(
                          tooltip: t.download,
                          icon: const Icon(Icons.download_rounded),
                          onPressed: () => downloader.add(incompletedContents),
                        ),
                PopupMenuButton<void>(
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      child: Text(t.open_in_folder),
                      onTap: () async {
                        final result = await openExplorer(
                          dir: currentDownloads[0].directory,
                        );
                        if (!result && context.mounted) {
                          logger('Could not open directory');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.cannot_open_in_folder)),
                          );
                        }
                      },
                    ),
                    PopupMenuItem<void>(
                      child: Text(t.delete),
                      onTap: () => downloader.remove(allContents),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/content',
                arguments: ContentPageProps(content: content, initialIndex: 1),
              );
            },
          );
        },
      ),
    );
  }
}
