import 'package:fnps/l10n/app_localizations.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/models/download_item.dart';

String formatDownloadItemStatus(
  DownloadItem item,
  AppLocalizations t,
  Pkg2zipOutputMode outputMode,
) {
  if (item.downloadStatus != DownloadStatus.completed) {
    final String progress =
        (item.totalLength > 0 && item.completedLength > 0)
        ? (item.completedLength / item.totalLength * 100)
              .clamp(0.0, 100.0)
              .toStringAsFixed(2)
        : '0.00';

    switch (item.downloadStatus) {
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
  }

  final bool isFolder = outputMode == Pkg2zipOutputMode.folder;
  switch (item.extractStatus) {
    case ExtractStatus.queued:
      return isFolder ? t.extract_queued : t.convert_queued;
    case ExtractStatus.extracting:
      return isFolder ? t.extracting : t.converting;
    case ExtractStatus.completed:
      return isFolder ? t.extract_completed : t.convert_completed;
    case ExtractStatus.failed:
      return isFolder ? t.extract_failed : t.convert_failed;
    case ExtractStatus.notNeeded:
      return t.download_completed;
  }
}
