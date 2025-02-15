import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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

class ContentList extends HookWidget {
  const ContentList({
    super.key,
    required this.contents,
    this.scroll = true,
  });

  final List<Content> contents;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);

    final downloadBox =
        useMemoized(() => Hive.box<DownloadItem>(downloadBoxName));
    final downloads = useListenable(downloadBox.listenable()).value;

    final downloader = useMemoized(() => Downloader.instance);

    return ListView.builder(
      shrinkWrap: true,
      physics: scroll ? null : const NeverScrollableScrollPhysics(),
      itemCount: contents.length,
      padding: const EdgeInsets.only(bottom: 96),
      itemBuilder: (context, index) {
        final content = contents[index];
        final DownloadItem? downloadItem = downloads.get(content.getID());
        return ListTile(
          // leading: ClipRRect(
          //   borderRadius: BorderRadius.circular(8),
          //   child: AspectRatio(
          //     aspectRatio: 1,
          //     child: CachedNetworkImage(
          //       imageUrl: getContentIcon(content, size: 96)!,
          //       fit: BoxFit.contain,
          //       placeholder: (context, url) => const SizedBox(
          //         child: Center(child: Icon(Icons.gamepad)),
          //       ),
          //       errorWidget: (context, url, error) => const Icon(Icons.gamepad),
          //     ),
          //   ),
          // ),
          title: Text(content.category == Category.update
              ? '${content.name} ${content.version}'
              : content.name),
          subtitle: Row(children: [
            CustomBadge(text: content.category.name),
            if (content.pkgDirectLink != null) const SizedBox(width: 4),
            if (content.pkgDirectLink != null)
              CustomBadge(text: fileSizeConv(content.fileSize)!),
            const SizedBox(width: 4),
            if (downloadItem != null &&
                downloadItem.downloadStatus != DownloadStatus.completed)
              CustomBadge(text: () {
                switch (downloadItem.downloadStatus) {
                  case DownloadStatus.queued:
                    return '${t.download_queued} ${(downloadItem.progress * 100).toStringAsFixed(2)}%';
                  case DownloadStatus.downloading:
                    return '${t.downloading} ${(downloadItem.progress * 100).toStringAsFixed(2)}%';
                  case DownloadStatus.completed:
                    return '${t.download_completed} ${(downloadItem.progress * 100).toStringAsFixed(2)}%';
                  case DownloadStatus.failed:
                    return '${t.download_failed} ${(downloadItem.progress * 100).toStringAsFixed(2)}%';
                  case DownloadStatus.paused:
                    return '${t.download_paused} ${(downloadItem.progress * 100).toStringAsFixed(2)}%';
                  case DownloadStatus.canceled:
                    return '${t.download_canceled} ${(downloadItem.progress * 100).toStringAsFixed(2)}%';
                }
              }()),
            if (downloadItem != null &&
                downloadItem.downloadStatus == DownloadStatus.completed)
              CustomBadge(text: () {
                switch (downloadItem.extractStatus) {
                  case ExtractStatus.queued:
                    return t.extract_queued;
                  case ExtractStatus.extracting:
                    return t.extracting;
                  case ExtractStatus.completed:
                    return t.extract_completed;
                  case ExtractStatus.failed:
                    return t.extract_failed;
                }
              }())
          ]),
          onTap: () => Navigator.pushNamed(context, '/content',
              arguments: ContentPageProps(content: content)),
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
                        icon: const Icon(Icons.download),
                        onPressed: () => downloader.add([content]),
                      );
                    case DownloadStatus.queued:
                    case DownloadStatus.downloading:
                      return IconButton(
                        icon: const Icon(Icons.pause),
                        onPressed: () => downloader.pause([content]),
                      );
                    case DownloadStatus.completed:
                      switch (downloadItem!.extractStatus) {
                        case ExtractStatus.queued:
                        case ExtractStatus.extracting:
                          return const SizedBox();
                        case ExtractStatus.completed:
                          return IconButton(
                            tooltip: t.remove_downloaded_pkg,
                            icon: const Icon(Icons.delete),
                            onPressed: () => downloader.remove([content]),
                          );
                        case ExtractStatus.failed:
                          return IconButton(
                            icon: const Icon(Icons.restart_alt),
                            onPressed: () => downloader.add([content]),
                          );
                      }
                  }
                }(),
              if (content.pkgDirectLink != null || content.zRIF != null)
                PopupMenuButton(
                  itemBuilder: (context) => [
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
                    if (downloadItem?.downloadStatus ==
                            DownloadStatus.completed &&
                        downloadItem?.extractStatus != ExtractStatus.extracting)
                      PopupMenuItem(
                        child: Text(t.re_extract),
                        onTap: () => downloader.add([content]),
                      ),
                    if (downloadItem != null)
                      PopupMenuItem(
                        child: Text(t.remove_downloaded_pkg),
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
