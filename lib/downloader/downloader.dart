import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:fnps/downloader/aria2.dart';
import 'package:fnps/models/aria2.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/rap.dart';
import 'package:hive_ce/hive.dart';
import 'package:fnps/downloader/create_download_item.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';
import 'package:fnps/utils/pkg.dart';

class Aria2Safe {
  static Future<void> remove(String gid) async {
    try {
      await Aria2.instance.remove(gid);
    } catch (e) {
      if (e.toString().contains('code: 1') ||
          e.toString().contains('not found')) {
        return;
      }
      logger('Aria2Safe remove error (ignored): $e');
    }
  }

  static Future<void> pause(String gid) async {
    try {
      await Aria2.instance.pause(gid);
    } catch (e) {
      if (e.toString().contains('code: 1') ||
          e.toString().contains('not found')) {
        return;
      }
      logger('Aria2Safe pause error (ignored): $e');
    }
  }

  static Future<void> cleanResult(String gid) async {
    try {
      await Aria2.instance.removeDownloadResult(gid);
    } catch (e) {
      if (e.toString().contains('code: 1') ||
          e.toString().contains('not found')) {
        return;
      }
      // logger('Aria2Safe cleanResult warning: $e');
    }
  }
}

class Downloader {
  Downloader._privateConstructor();

  static final Downloader _instance = Downloader._privateConstructor();

  static Downloader get instance => _instance;

  Box<DownloadItem> downloadBox = Hive.box<DownloadItem>(downloadBoxName);

  final Queue<Content> _queue = Queue();
  int maxConcurrentTasks = 3;

  final Map<String, String> gidToItemId = {}; // gid -> downloadItem.id

  Timer? _pollingTimer;
  bool _isPolling = false;
  Duration pollInterval = Duration(milliseconds: 1500);

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

  void _startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    logger('Starting polling...');

    _pollingTimer = Timer.periodic(pollInterval, (timer) async {
      try {
        final globalStat = await Aria2.instance.getGlobalStat();

        if (globalStat.numActive == 0 &&
            globalStat.numStopped == 0 &&
            _queue.isEmpty) {
          logger('Idle state detected, stopping polling...');
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

        if (gidToItemId.length < maxConcurrentTasks && _queue.isNotEmpty) {
          logger(
            'Polling Scheduler: Slots available (${gidToItemId.length}/$maxConcurrentTasks), starting next task...',
          );
          _start();
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

  Future<void> add(List<Content> contents) async {
    for (final content in contents) {
      final id = content.getID();
      if (id == null) continue;

      DownloadItem? existingItem = downloadBox.get(id);

      if (existingItem != null) {
        if (existingItem.downloadStatus == DownloadStatus.downloading ||
            _queue.contains(content)) {
          logger('Already downloading/queued $id...');
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
    if (gidToItemId.length >= maxConcurrentTasks || _queue.isEmpty) {
      return;
    }

    while (gidToItemId.length < maxConcurrentTasks && _queue.isNotEmpty) {
      final content = _queue.removeFirst();
      logger(
        'Starting task: ${gidToItemId.length + 1} / $maxConcurrentTasks, Queue size: ${_queue.length}',
      );

      _download(content);

      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  Future<void> pause(List<Content> contents) async {
    _queue.removeWhere((item) => contents.toSet().contains(item));

    for (final content in contents) {
      final downloadItem = downloadBox.get(content.getID());

      if (downloadItem == null ||
          [
            DownloadStatus.canceled,
            DownloadStatus.completed,
            DownloadStatus.failed,
          ].contains(downloadItem.downloadStatus)) {
        continue;
      }

      logger('Pausing ${downloadItem.id}...');

      String? gid;
      gidToItemId.forEach((key, value) {
        if (value == downloadItem.id) gid = key;
      });

      if (gid != null) {
        await Aria2Safe.pause(gid!);
      }

      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.paused),
      );
    }
  }

  Future<void> remove(List<Content> contents) async {
    _queue.removeWhere((item) => contents.toSet().contains(item));

    for (final content in contents) {
      try {
        final downloadItem = downloadBox.get(content.getID());
        if (downloadItem != null) {
          String? gid;
          gidToItemId.forEach((key, value) {
            if (value == downloadItem.id) gid = key;
          });

          if (gid != null) {
            try {
              await Aria2Safe.remove(gid!);
              await Aria2Safe.cleanResult(gid!);
              logger('Aria2 task removed request sent: gid=$gid');
            } finally {
              if (gidToItemId.containsKey(gid)) {
                gidToItemId.remove(gid);
              }
            }
          }

          await downloadBox.delete(content.getID());

          final String filePath = pathJoin([
            ...downloadItem.directory,
            downloadItem.filename,
          ]);
          final String aria2FilePath = '$filePath.aria2';

          try {
            final f = File(filePath);
            if (await f.exists()) await f.delete();
          } catch (e) {
            logger('Failed delete file: $filePath', error: e);
          }

          try {
            final f = File(aria2FilePath);
            if (await f.exists()) await f.delete();
          } catch (e) {
            logger('Failed delete aria2 file: $aria2FilePath', error: e);
          }
        }
        logger('Removed ${content.getID()} successfully.');
      } catch (e) {
        logger('Error removing download item: $e');
      }
    }

    _start();
  }

  Future<void> _download(Content content) async {
    final String? url = content.pkgDirectLink;
    if (url == null) {
      _start();
      return;
    }

    bool success = false;
    String? gid;

    try {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      if (downloadItem == null) {
        _start();
        return;
      }

      logger('Starting download for ${content.name}');

      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.downloading),
      );

      final String dir = pathJoin(downloadItem.directory);
      final String filename = downloadItem.filename;

      gid = await Aria2.instance.addUri(url, dir, filename);

      gidToItemId[gid] = downloadItem.id;
      success = true;

      logger('Download added to aria2: gid=$gid, file=$filename');

      if (!_isPolling) {
        _startPolling();
      }
    } catch (e) {
      logger('Failed to add download to aria2: ${content.getID()}', error: e);

      DownloadItem? downloadItem = downloadBox.get(content.getID());
      if (downloadItem != null) {
        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(downloadStatus: DownloadStatus.failed),
        );
      }

      if (gid != null) {
        gidToItemId.remove(gid);
      }
    } finally {
      if (!success) {
        _start();
      }
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
    if (itemId == null) {
      await Aria2Safe.cleanResult(status.gid);
      return;
    }

    final downloadItem = downloadBox.get(itemId);
    if (downloadItem == null) {
      gidToItemId.remove(status.gid);
      await Aria2Safe.cleanResult(status.gid);
      return;
    }

    if (downloadItem.extractStatus == ExtractStatus.extracting ||
        downloadItem.extractStatus == ExtractStatus.completed ||
        downloadItem.extractStatus == ExtractStatus.notNeeded) {
      gidToItemId.remove(status.gid);
      await Aria2Safe.cleanResult(status.gid);

      _start();
      return;
    }

    try {
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
          logger('Extract failed for: ${status.gid}');
        }
      } else if (status.status == 'error') {
        logger('Download error [${status.gid}]: ${downloadItem.filename}');
        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(downloadStatus: DownloadStatus.failed),
        );
      }
    } finally {
      await Aria2Safe.cleanResult(status.gid);
      if (gidToItemId.containsKey(status.gid)) {
        gidToItemId.remove(status.gid);
      }

      _start();
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

    final config = await ConfigProvider().loadConfig();

    final result = await pkg2zip(
      path: path,
      extract: config.pkg2zipOutputMode == Pkg2zipOutputMode.folder,
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
