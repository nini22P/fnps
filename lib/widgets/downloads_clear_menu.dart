import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/downloader/downloader.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/utils/get_localizations.dart';

enum DownloadsClearAction { completed, all }

class DownloadsClearMenu extends HookWidget {
  final List<DownloadItem> downloadItems;

  const DownloadsClearMenu({super.key, required this.downloadItems});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final downloader = Downloader.instance;

    void performClear(List<DownloadItem> items) {
      downloader.remove(items.map((e) => e.content).toList());
    }

    void showConfirmDialog(
      List<DownloadItem> items, {
      required bool isAll,
      required bool hasActiveDownloads,
    }) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.clear_confirm_title),
          content: Text(
            isAll && hasActiveDownloads
                ? t.clear_all_warning_msg
                : t.clear_confirm_msg,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.cancel),
            ),
            TextButton(
              onPressed: () {
                performClear(items);
                Navigator.pop(context);
              },
              child: Text(
                t.confirm,
                style: TextStyle(color: isAll ? Colors.red : null),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<DownloadsClearAction>(
      icon: const Icon(Icons.cleaning_services_rounded),
      tooltip: t.clear_downloads,
      onSelected: (action) {
        if (action == DownloadsClearAction.completed) {
          final completedItems = downloadItems
              .where(
                (item) =>
                    item.extractStatus == ExtractStatus.completed ||
                    item.extractStatus == ExtractStatus.notNeeded,
              )
              .toList();

          if (completedItems.isNotEmpty) {
            performClear(completedItems);
          }
        } else if (action == DownloadsClearAction.all) {
          final bool hasActiveDownloads = downloadItems.any(
            (item) => item.downloadStatus == DownloadStatus.downloading,
          );

          showConfirmDialog(
            downloadItems,
            isAll: true,
            hasActiveDownloads: hasActiveDownloads,
          );
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: DownloadsClearAction.completed,
            child: Text(t.clear_completed),
          ),
          PopupMenuItem(
            value: DownloadsClearAction.all,
            child: Text(t.clear_all, style: const TextStyle(color: Colors.red)),
          ),
        ];
      },
    );
  }
}
