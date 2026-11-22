import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:fnps/downloader/chunk_downloader.dart';
import 'package:fnps/downloader/create_download_item.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';
import 'package:fnps/utils/pkg.dart';
import 'package:fnps/utils/rap.dart';
import 'package:hive_ce/hive.dart';

class Downloader {
  Downloader._privateConstructor();

  static final Downloader _instance = Downloader._privateConstructor();

  static Downloader get instance => _instance;

  Box<DownloadItem> downloadBox = Hive.box<DownloadItem>(downloadBoxName);

  final Queue<Content> _queue = Queue<Content>();
  final Map<String, ChunkDownloadTask> _activeTasks =
      <String, ChunkDownloadTask>{};
  final Map<String, Future<void>> _activeFutures = <String, Future<void>>{};
  final Map<String, DateTime> _lastFlushTime = <String, DateTime>{};

  int maxConcurrentTasks = 3;
  Duration _flushInterval = const Duration(milliseconds: 1000);

  Future<void> init() async {
    final List<DownloadItem> downloads = downloadBox.values.toList();
    for (final DownloadItem download in downloads) {
      if (<DownloadStatus>[
        DownloadStatus.downloading,
        DownloadStatus.queued,
      ].contains(download.downloadStatus)) {
        await downloadBox.put(
          download.id,
          download.copyWith(downloadStatus: DownloadStatus.paused),
        );
      } else if (download.downloadStatus == DownloadStatus.completed &&
          <ExtractStatus>[
            ExtractStatus.queued,
            ExtractStatus.extracting,
          ].contains(download.extractStatus)) {
        await downloadBox.put(
          download.id,
          download.copyWith(extractStatus: ExtractStatus.failed),
        );
      }
    }
  }

  void setPollInterval(Duration duration) {
    if (_flushInterval == duration) return;
    _flushInterval = duration;
  }

  bool _isQueued(String id) => _queue.any((Content item) => item.getID() == id);

  Future<void> add(List<Content> contents) async {
    for (final Content content in contents) {
      final String? id = content.getID();
      if (id == null) continue;

      final DownloadItem? existingItem = downloadBox.get(id);

      if (existingItem != null) {
        if (_activeTasks.containsKey(id) ||
            existingItem.downloadStatus == DownloadStatus.downloading ||
            _isQueued(id)) {
          logger('Already downloading/queued $id...');
          continue;
        }

        if (<DownloadStatus>[
          DownloadStatus.paused,
          DownloadStatus.failed,
          DownloadStatus.canceled,
        ].contains(existingItem.downloadStatus)) {
          logger('Resuming download $id...');
          await downloadBox.put(
            existingItem.id,
            existingItem.copyWith(downloadStatus: DownloadStatus.queued),
          );
          _queue.add(content);
          continue;
        }

        if (existingItem.downloadStatus == DownloadStatus.completed &&
            existingItem.extractStatus == ExtractStatus.failed) {
          final String pkgPath = pathJoin(<String>[
            ...existingItem.directory,
            existingItem.filename,
          ]);
          final File pkgFile = File(pkgPath);

          if (await pkgFile.exists()) {
            logger('Re-extracting $id...');
            unawaited(_extractDownload(existingItem));
            continue;
          } else {
            logger('PKG file not found, re-downloading $id...');
            await downloadBox.put(
              existingItem.id,
              existingItem.copyWith(
                downloadStatus: DownloadStatus.queued,
                extractStatus: ExtractStatus.queued,
                completedLength: 0,
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

      final DownloadItem? downloadItem = await createDownloadItem(content);
      if (downloadItem == null) continue;

      logger('Adding $id to download queue...');
      await downloadBox.put(downloadItem.id, downloadItem);
      _queue.add(content);
    }

    _start();
  }

  void _start() {
    while (_activeTasks.length < maxConcurrentTasks && _queue.isNotEmpty) {
      final Content content = _queue.removeFirst();
      final String? id = content.getID();
      final String? url = content.pkgDirectLink;
      if (id == null || url == null || _activeTasks.containsKey(id)) {
        continue;
      }

      final DownloadItem? downloadItem = downloadBox.get(id);
      if (downloadItem == null) {
        continue;
      }

      final String filePath = pathJoin(<String>[
        ...downloadItem.directory,
        downloadItem.filename,
      ]);
      final ChunkDownloadTask task = ChunkDownloadTask(
        url: url,
        savePath: filePath,
      );
      _activeTasks[id] = task;

      logger(
        'Starting task: ${_activeTasks.length} / $maxConcurrentTasks, Queue size: ${_queue.length}',
      );

      _activeFutures[id] = _download(content, id, downloadItem, task);
    }
  }

  Future<void> pause(List<Content> contents) async {
    final Set<String> targetIds = contents
        .map((Content e) => e.getID())
        .whereType<String>()
        .toSet();
    _queue.removeWhere((Content item) => targetIds.contains(item.getID()));

    for (final Content content in contents) {
      final String? id = content.getID();
      if (id == null) continue;

      final DownloadItem? downloadItem = downloadBox.get(id);
      if (downloadItem == null ||
          <DownloadStatus>[
            DownloadStatus.canceled,
            DownloadStatus.completed,
            DownloadStatus.failed,
          ].contains(downloadItem.downloadStatus)) {
        continue;
      }

      logger('Pausing $id...');
      _activeTasks[id]?.pause();

      await downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.paused),
      );
    }
  }

  Future<void> remove(List<Content> contents) async {
    final Set<String> targetIds = contents
        .map((Content e) => e.getID())
        .whereType<String>()
        .toSet();
    _queue.removeWhere((Content item) => targetIds.contains(item.getID()));

    for (final Content content in contents) {
      final String? id = content.getID();
      if (id == null) continue;

      try {
        final DownloadItem? downloadItem = downloadBox.get(id);
        final ChunkDownloadTask? activeTask = _activeTasks[id];
        final Future<void>? activeFuture = _activeFutures[id];

        if (activeTask != null) {
          activeTask.cancel();
        }
        if (activeFuture != null) {
          await activeFuture;
        }

        if (downloadItem != null) {
          await downloadBox.delete(id);

          final String filePath = pathJoin(<String>[
            ...downloadItem.directory,
            downloadItem.filename,
          ]);

          await ChunkDownloadTask.cleanupTempFiles(filePath);

          try {
            final File f = File(filePath);
            if (await f.exists()) await f.delete();
          } catch (e) {
            logger('Failed delete file: $filePath', error: e);
          }
        }
        logger('Removed $id successfully.');
      } catch (e) {
        logger('Error removing download item: $e');
      }
    }

    _start();
  }

  Future<void> _download(
    Content content,
    String id,
    DownloadItem downloadItem,
    ChunkDownloadTask task,
  ) async {
    try {
      logger('Starting download for ${content.name}');

      await downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.downloading),
      );

      final ChunkDownloadResult result = await task.start(
        onProgress: (int completed, int total) {
          final DateTime now = DateTime.now();
          final DateTime? lastFlush = _lastFlushTime[id];
          if (lastFlush != null && now.difference(lastFlush) < _flushInterval) {
            return;
          }
          _lastFlushTime[id] = now;

          final DownloadItem? current = downloadBox.get(id);
          if (current == null ||
              current.downloadStatus != DownloadStatus.downloading) {
            return;
          }

          downloadBox.put(
            current.id,
            current.copyWith(
              totalLength: total > 0 ? total : current.totalLength,
              completedLength: completed,
            ),
          );
        },
      );

      final DownloadItem? latest = downloadBox.get(id);
      if (latest == null) return;

      switch (result.status) {
        case ChunkDownloadStatus.completed:
          logger('Download completed: ${latest.filename}');
          final int finalTotal = result.totalLength > 0
              ? result.totalLength
              : latest.totalLength;
          final DownloadItem completedItem = latest.copyWith(
            totalLength: finalTotal,
            completedLength: finalTotal,
            downloadStatus: DownloadStatus.completed,
          );
          await downloadBox.put(latest.id, completedItem);

          final bool extracted = await _extractDownload(completedItem);
          if (!extracted) {
            logger('Extract failed for: $id');
          }
          break;

        case ChunkDownloadStatus.paused:
          await downloadBox.put(
            latest.id,
            latest.copyWith(
              totalLength: result.totalLength > 0
                  ? result.totalLength
                  : latest.totalLength,
              completedLength: result.completedLength > 0
                  ? result.completedLength
                  : latest.completedLength,
              downloadStatus: DownloadStatus.paused,
            ),
          );
          break;

        case ChunkDownloadStatus.canceled:
          break;

        case ChunkDownloadStatus.failed:
          logger(
            'Download error [$id]: ${latest.filename}',
            error: result.errorMessage,
          );
          await downloadBox.put(
            latest.id,
            latest.copyWith(
              totalLength: result.totalLength > 0
                  ? result.totalLength
                  : latest.totalLength,
              completedLength: result.completedLength > 0
                  ? result.completedLength
                  : latest.completedLength,
              downloadStatus: DownloadStatus.failed,
            ),
          );
          break;
      }
    } catch (e) {
      logger('Failed to download $id', error: e);
      final DownloadItem? current = downloadBox.get(id);
      if (current != null) {
        await downloadBox.put(
          current.id,
          current.copyWith(downloadStatus: DownloadStatus.failed),
        );
      }
    } finally {
      _activeTasks.remove(id);
      _activeFutures.remove(id);
      _lastFlushTime.remove(id);
      _start();
    }
  }

  Future<bool> _extractDownload(DownloadItem downloadItem) async {
    final List<String> path = <String>[
      ...downloadItem.directory,
      downloadItem.filename,
    ];

    await downloadBox.put(
      downloadItem.id,
      downloadItem.copyWith(extractStatus: ExtractStatus.extracting),
    );

    try {
      final String? pkgName = await getPkgName(path);
      logger('pkgName: $pkgName');
    } catch (e) {
      logger('getPkgName failed:', error: e);
    }

    final Config config = await ConfigProvider().loadConfig();

    final bool result = await pkg2zip(
      path: path,
      extract: config.pkg2zipOutputMode == Pkg2zipOutputMode.folder,
      zRIF: downloadItem.content.zRIF,
    );

    if (result) {
      await downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(extractStatus: ExtractStatus.completed),
      );

      final File file = File(pathJoin(path));
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

      final ExtractStatus extractStatus =
          downloadItem.content.platform == Platform.ps3
          ? ExtractStatus.notNeeded
          : ExtractStatus.failed;

      await downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(extractStatus: extractStatus),
      );

      return extractStatus == ExtractStatus.notNeeded;
    }
  }
}
