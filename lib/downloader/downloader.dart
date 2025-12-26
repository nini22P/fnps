import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:fnps/downloader/aria2.dart';
import 'package:fnps/models/aria2.dart';
import 'package:fnps/utils/rap.dart';
import 'package:hive_ce/hive.dart';
import 'package:fnps/downloader/create_download_item.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';
import 'package:fnps/utils/pkg.dart';

class Downloader {
  Downloader._privateConstructor();

  static final Downloader _instance = Downloader._privateConstructor();

  static Downloader get instance => _instance;

  Box<DownloadItem> downloadBox = Hive.box<DownloadItem>(downloadBoxName);

  final Queue<Content> _queue = Queue();
  int maxConcurrentTasks = 3;
  int runningTasks = 0;

  final Map<String, String> gidToItemId = {}; // gid -> downloadItem.id

  Timer? _pollingTimer;
  bool _isPolling = false;
  Duration pollInterval = Duration(milliseconds: 1500);

  void _startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    logger('Starting polling...');

    _pollingTimer = Timer.periodic(pollInterval, (timer) async {
      try {
        final globalStat = await Aria2.instance.getGlobalStat();

        logger('Aria2 global stat: $globalStat');

        if (globalStat.numActive == 0 && globalStat.numStopped == 0) {
          logger('No active tasks, stopping polling...');
          _stopPolling();
          return;
        }

        if (globalStat.numActive != 0) {
          final active = await Aria2.instance.tellActive();
          for (final status in active) {
            _updateDownloadStatus(status);
          }
        }

        // if (globalStat.numWaiting != 0) {
        //   final waiting = await Aria2.instance.tellWaiting();
        // }

        if (globalStat.numStopped != 0) {
          final stopped = await Aria2.instance.tellStopped();
          for (final status in stopped) {
            await _handleStoppedStatus(status);
          }
        }
      } catch (e) {
        logger("Aria2 polling error: $e");
      }
    });
  }

  void _stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      _isPolling = false;
      logger('Polling stopped');
    }
  }

  void setPollInterval(Duration duration) {
    if (pollInterval == duration) return;

    logger('Updating poll interval to: ${duration.inMilliseconds}ms');
    pollInterval = duration;

    if (_isPolling) {
      _stopPolling();
      _startPolling();
    }
  }

  Future<void> init() async {
    final downloads = downloadBox.values.toList();
    for (final download in downloads) {
      if ([
        DownloadStatus.downloading,
        DownloadStatus.queued,
      ].contains(download.downloadStatus)) {
        downloadBox.put(
          download.id,
          download.copyWith(downloadStatus: DownloadStatus.paused),
        );
      } else if (download.downloadStatus == DownloadStatus.completed &&
          [
            ExtractStatus.queued,
            ExtractStatus.extracting,
          ].contains(download.extractStatus)) {
        downloadBox.put(
          download.id,
          download.copyWith(extractStatus: ExtractStatus.failed),
        );
      }
    }
  }

  Future<void> add(List<Content> contents) async {
    for (final content in contents) {
      final id = content.getID();
      if (id == null) continue;

      DownloadItem? existingItem = downloadBox.get(id);

      if (existingItem != null) {
        if (existingItem.downloadStatus == DownloadStatus.downloading ||
            _queue.contains(content)) {
          logger('Already downloading $id...');
          continue;
        }

        if ([
          DownloadStatus.paused,
          DownloadStatus.failed,
          DownloadStatus.canceled,
        ].contains(existingItem.downloadStatus)) {
          logger('Resuming download $id...');
          downloadBox.put(
            existingItem.id,
            existingItem.copyWith(downloadStatus: DownloadStatus.queued),
          );
          _queue.add(content);
          continue;
        }

        if (existingItem.downloadStatus == DownloadStatus.completed &&
            existingItem.extractStatus == ExtractStatus.failed) {
          final pkgPath = pathJoin([
            ...existingItem.directory,
            existingItem.filename,
          ]);
          final pkgFile = File(pkgPath);

          if (await pkgFile.exists()) {
            logger('Re-extracting $id...');
            await _extractDownload(existingItem);
            continue;
          } else {
            logger('PKG file not found, re-downloading $id...');
            downloadBox.put(
              existingItem.id,
              existingItem.copyWith(
                downloadStatus: DownloadStatus.queued,
                extractStatus: ExtractStatus.queued,
              ),
            );
            _queue.add(content);
            continue;
          }
        }

        logger(
          'Download already exists with status: ${existingItem.downloadStatus}',
        );
        continue;
      }

      final downloadItem = await createDownloadItem(content);
      if (downloadItem == null) continue;

      logger('Adding $id to download queue...');
      await downloadBox.put(downloadItem.id, downloadItem);
      _queue.add(content);
    }

    _start();
  }

  Future<void> _start() async {
    if (runningTasks >= maxConcurrentTasks || _queue.isEmpty) {
      return;
    }

    while (runningTasks < maxConcurrentTasks && _queue.isNotEmpty) {
      final content = _queue.removeFirst();
      runningTasks++;
      logger('Running task: $runningTasks');
      download(content);
      await Future.delayed(const Duration(milliseconds: 500), null);
    }
  }

  Future<void> pause(List<Content> contents) async {
    for (final content in contents) {
      final downloadItem = downloadBox.get(content.getID());
      final id = downloadItem?.id;
      if (downloadItem == null ||
          id == null ||
          [
            DownloadStatus.canceled,
            DownloadStatus.completed,
            DownloadStatus.failed,
          ].contains(downloadItem.downloadStatus)) {
        continue;
      }

      logger('Pausing $id...');

      String? gid;
      gidToItemId.forEach((key, value) {
        if (value == id) {
          gid = key;
        }
      });

      if (gid != null) {
        try {
          await Aria2.instance.pause(gid!);

          downloadBox.put(
            downloadItem.id,
            downloadItem.copyWith(downloadStatus: DownloadStatus.paused),
          );
          logger('Aria2 pause called for gid=$gid');
        } catch (e) {
          logger('Failed to pause aria2 task: $gid', error: e);
        }
      }

      if (_queue.contains(content)) {
        _queue.remove(content);
      }
    }
  }

  Future<void> remove(List<Content> contents) async {
    for (final content in contents) {
      try {
        final downloadItem = downloadBox.get(content.getID());
        if (downloadItem != null) {
          await pause([content]);

          final String filePath = pathJoin([
            ...downloadItem.directory,
            downloadItem.filename,
          ]);
          final String aria2FilePath = '$filePath.aria2';

          File file = File(filePath);
          File aria2File = File(aria2FilePath);

          try {
            if (await file.exists()) await file.delete();
          } catch (e) {
            logger('Not delete file: $filePath', error: e);
          }

          try {
            if (await aria2File.exists()) await aria2File.delete();
          } catch (e) {
            logger('Not delete aria2 file: $aria2FilePath', error: e);
          }

          String? gid;
          gidToItemId.forEach((key, value) {
            if (value == downloadItem.id) {
              gid = key;
            }
          });

          if (gid != null) {
            try {
              await Aria2.instance.remove(gid!);
              await Aria2.instance.removeDownloadResult(gid!);
              gidToItemId.remove(gid);
              logger('Aria2 task removed: gid=$gid');
            } catch (e) {
              logger('Failed to remove aria2 task: $gid', error: e);
            }
          }

          await downloadBox.delete(content.getID());
        }
        logger('Removed ${content.getID()} from download queue...');
      } catch (e) {
        logger('Error cancelling download: $e');
      }
    }
  }

  Future<void> download(Content content) async {
    final String? url = content.pkgDirectLink;
    if (url == null) return;

    try {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      final id = downloadItem?.id;
      if (downloadItem == null || id == null) return;

      logger('Starting download for ${content.name}');

      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.downloading),
      );

      final String dir = pathJoin(downloadItem.directory);
      final String filename = downloadItem.filename;

      final String gid = await Aria2.instance.addUri(url, dir, filename);

      gidToItemId[gid] = id;

      logger('Download added to aria2: gid=$gid, file=$filename');

      if (!_isPolling) {
        _startPolling();
      }
    } catch (e) {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      if (downloadItem != null) {
        logger('Failed to add download to aria2: ${content.getID()}', error: e);
        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(downloadStatus: DownloadStatus.failed),
        );
      }
    } finally {
      runningTasks--;
      _start();
    }
  }

  void _updateDownloadStatus(Aria2Status status) {
    final itemId = gidToItemId[status.gid];
    if (itemId == null) return;

    final downloadItem = downloadBox.get(itemId);
    if (downloadItem == null) return;

    if (downloadItem.downloadStatus != DownloadStatus.downloading) return;

    downloadBox.put(
      downloadItem.id,
      downloadItem.copyWith(
        totalLength: status.totalLength,
        completedLength: status.completedLength,
      ),
    );
  }

  Future<void> _handleStoppedStatus(Aria2Status status) async {
    final itemId = gidToItemId[status.gid];
    if (itemId == null) return;

    final downloadItem = downloadBox.get(itemId);
    if (downloadItem == null) return;

    try {
      await Aria2.instance.removeDownloadResult(status.gid);
      gidToItemId.remove(status.gid);
    } catch (e) {
      logger('Failed to clean aria2 result: ${status.gid}', error: e);
    }

    if (downloadItem.extractStatus == ExtractStatus.extracting ||
        downloadItem.extractStatus == ExtractStatus.completed ||
        downloadItem.extractStatus == ExtractStatus.notNeeded) {
      return;
    }

    if (status.status == 'complete') {
      logger('Download completed: ${downloadItem.filename}');

      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(
          completedLength: downloadItem.totalLength,
          downloadStatus: DownloadStatus.completed,
        ),
      );

      final result = await _extractDownload(
        downloadItem.copyWith(
          completedLength: downloadItem.totalLength,
          downloadStatus: DownloadStatus.completed,
        ),
      );

      if (!result) {
        logger('Extract failed, keeping aria2 result for retry: ${status.gid}');
      }
    } else if (status.status == 'error') {
      logger('Download error: ${downloadItem.filename}');
      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.failed),
      );
    }
  }

  Future<bool> _extractDownload(DownloadItem downloadItem) async {
    final List<String> path = [
      ...downloadItem.directory,
      downloadItem.filename,
    ];

    downloadBox.put(
      downloadItem.id,
      downloadItem.copyWith(extractStatus: ExtractStatus.extracting),
    );

    try {
      final pkgName = await getPkgName(path);
      logger('pkgName: $pkgName');
    } catch (e) {
      logger('getPkgName failed:', error: e);
    }

    final result = await pkg2zip(
      path: path,
      extract:
          downloadItem.content.platform == Platform.psv &&
              downloadItem.content.category == Category.theme
          ? false
          : true,
      zRIF: downloadItem.content.zRIF,
    );

    if (result) {
      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(extractStatus: ExtractStatus.completed),
      );

      final file = File(pathJoin(path));
      if (await file.exists()) {
        await file.delete();
      }

      return true;
    } else {
      if (downloadItem.content.platform == Platform.ps3 &&
          downloadItem.content.category != Category.update &&
          downloadItem.content.rap != null &&
          downloadItem.content.rap!.isNotEmpty) {
        await downloadRAP(downloadItem.content);
      }

      final extractStatus = downloadItem.content.platform == Platform.ps3
          ? ExtractStatus.notNeeded
          : ExtractStatus.failed;

      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(extractStatus: extractStatus),
      );

      return extractStatus == ExtractStatus.notNeeded;
    }
  }
}
