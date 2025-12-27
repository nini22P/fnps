import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/content_info.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/open_explorer.dart';
import 'package:fnps/utils/rap.dart';
import 'package:fnps/widgets/custom_badge.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:fnps/downloader/downloader.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/pages/content_page/content_page.dart';
import 'package:fnps/utils/copy_to_clipboard.dart';
import 'package:fnps/utils/file_size_convert.dart';
import 'package:fnps/utils/get_localizations.dart';
import 'package:provider/provider.dart';

class ContentList extends HookWidget {
  const ContentList({super.key, required this.contents, this.scroll = true});

  final List<Content> contents;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final downloadBox = useMemoized(
      () => Hive.box<DownloadItem>(downloadBoxName),
    );
    final downloads = useListenable(downloadBox.listenable()).value;

    final downloader = useMemoized(() => Downloader.instance);

    final pkg2zipOutputMode = context.select<ConfigProvider, Pkg2zipOutputMode>(
      (provider) => provider.config.pkg2zipOutputMode,
    );

    return ListView.builder(
      shrinkWrap: true,
      physics: scroll ? null : const NeverScrollableScrollPhysics(),
      itemCount: contents.length,
      padding: const EdgeInsets.only(bottom: 96),
      itemBuilder: (context, index) {
        final content = contents[index];
        final contentId = content.getID();
        final DownloadItem? downloadItem = contentId != null
            ? downloads.get(contentId)
            : null;
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
          title: Text(
            content.category == Category.update
                ? '${content.name}${content.version != null ? ' ${content.version}' : ''}'
                : content.name,
          ),
          subtitle: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              CustomBadge(text: content.category.name, tertiary: true),
              if (content.pkgDirectLink != null)
                CustomBadge(text: fileSizeConv(content.fileSize)!),
              if (downloadItem != null &&
                  downloadItem.downloadStatus != DownloadStatus.completed)
                CustomBadge(
                  text: () {
                    final progress =
                        (downloadItem.totalLength > 0 &&
                            downloadItem.completedLength > 0)
                        ? (downloadItem.completedLength /
                                  downloadItem.totalLength *
                                  100)
                              .toStringAsFixed(2)
                        : '0.00';
                    switch (downloadItem.downloadStatus) {
                      case DownloadStatus.queued:
                        return '${t.download_queued} $progress%';
                      case DownloadStatus.downloading:
                        return '${t.downloading} $progress%';
                      case DownloadStatus.completed:
                        return '${t.download_completed} $progress%';
                      case DownloadStatus.failed:
                        return '${t.download_failed} $progress%';
                      case DownloadStatus.paused:
                        return '${t.download_paused} $progress%';
                      case DownloadStatus.canceled:
                        return '${t.download_canceled} $progress%';
                    }
                  }(),
                ),
              if (downloadItem != null &&
                  downloadItem.downloadStatus == DownloadStatus.completed)
                CustomBadge(
                  text: () {
                    switch (downloadItem.extractStatus) {
                      case ExtractStatus.queued:
                        return pkg2zipOutputMode == Pkg2zipOutputMode.folder
                            ? t.extract_queued
                            : t.convert_queued;
                      case ExtractStatus.extracting:
                        return pkg2zipOutputMode == Pkg2zipOutputMode.folder
                            ? t.extracting
                            : t.converting;
                      case ExtractStatus.completed:
                        return pkg2zipOutputMode == Pkg2zipOutputMode.folder
                            ? t.extract_completed
                            : t.convert_completed;
                      case ExtractStatus.failed:
                        return pkg2zipOutputMode == Pkg2zipOutputMode.folder
                            ? t.extract_failed
                            : t.convert_failed;
                      case ExtractStatus.notNeeded:
                        return t.download_completed;
                    }
                  }(),
                ),
            ],
          ),
          onTap: () => Navigator.pushNamed(
            context,
            '/content',
            arguments: ContentPageProps(content: content),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (content.pkgDirectLink != null)
                () {
                  switch (downloadItem?.downloadStatus) {
                    case null:
                    case DownloadStatus.failed:
                    case DownloadStatus.paused:
                    case DownloadStatus.canceled:
                      return IconButton(
                        icon: const Icon(Icons.download_rounded),
                        onPressed: () => downloader.add([content]),
                      );
                    case DownloadStatus.queued:
                    case DownloadStatus.downloading:
                      return IconButton(
                        icon: const Icon(Icons.pause_rounded),
                        onPressed: () => downloader.pause([content]),
                      );
                    case DownloadStatus.completed:
                      switch (downloadItem!.extractStatus) {
                        case ExtractStatus.queued:
                        case ExtractStatus.extracting:
                          return const SizedBox();
                        case ExtractStatus.completed:
                        case ExtractStatus.notNeeded:
                          return IconButton(
                            icon: const Icon(Icons.delete_rounded),
                            onPressed: () => downloader.remove([content]),
                          );
                        case ExtractStatus.failed:
                          return IconButton(
                            icon: const Icon(Icons.restart_alt_rounded),
                            onPressed: () => downloader.add([content]),
                          );
                      }
                  }
                }(),
              if (content.pkgDirectLink != null || content.zRIF != null)
                PopupMenuButton(
                  itemBuilder: (context) => [
                    if (downloadItem != null &&
                        downloadItem.downloadStatus != DownloadStatus.queued)
                      PopupMenuItem(
                        child: Text(t.open_in_folder),
                        onTap: () async {
                          final result = await openExplorer(
                            dir: downloadItem.directory,
                          );
                          if (!result && context.mounted) {
                            logger('Could not open directory');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(t.cannot_open_in_folder)),
                            );
                          }
                        },
                      ),
                    if (content.pkgDirectLink != null)
                      PopupMenuItem(
                        child: Text(t.copy_download_link),
                        onTap: () => copyToClipboard(
                          context,
                          '${content.pkgDirectLink}',
                          t.dlc_link_copied,
                        ),
                      ),
                    if (content.zRIF != null)
                      PopupMenuItem(
                        child: Text('${t.copy} zRIF'),
                        onTap: () => copyToClipboard(
                          context,
                          '${content.zRIF}',
                          t.zrif_copied,
                        ),
                      ),
                    if (content.contentID != null && content.rap != null)
                      PopupMenuItem(
                        child: Text('${t.copy} RAP ${t.download_link}'),
                        onTap: () => copyToClipboard(
                          context,
                          getRAPUrl(content.contentID!, content.rap!),
                          t.rap_download_link_copied,
                        ),
                      ),
                    if (content.rap != null)
                      PopupMenuItem(
                        child: Text('${t.download} RAP ${t.file}'),
                        onTap: () async {
                          final result = await downloadRAP(content);
                          if (result && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${t.downloaded} RAP ${t.file}'),
                              ),
                            );
                          }
                        },
                      ),
                    if (downloadItem?.downloadStatus ==
                            DownloadStatus.completed &&
                        downloadItem?.extractStatus == ExtractStatus.failed)
                      PopupMenuItem(
                        child: Text(
                          pkg2zipOutputMode == Pkg2zipOutputMode.folder
                              ? t.re_extract
                              : t.re_convert,
                        ),
                        onTap: () => downloader.add([content]),
                      ),
                    if (downloadItem != null)
                      PopupMenuItem(
                        child: Text(t.delete),
                        onTap: () => downloader.remove([content]),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
