import 'dart:developer';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/utils/path.dart';
import 'package:vita_dl/utils/pkg.dart';

class Downloader {
  Downloader._privateConstructor();

  static final Downloader _instance = Downloader._privateConstructor();

  static Downloader get instance => _instance;

  late FileDownloader _fileDownloader;
  late Box<DownloadItem> _downloadBox;
  late ValueNotifier<bool> _isPaused;

  final List<Content> _downloadQueue = [];
  final int _maxConcurrentDownloads = 3;
  int _activeDownloads = 0;

  Future<void> init() async {
    _fileDownloader = FileDownloader();
    _downloadBox = Hive.box<DownloadItem>(downloadBoxName);
    _isPaused = ValueNotifier<bool>(true);
  }

  FileDownloader get fileDownloader => _fileDownloader;

  ValueNotifier<bool> get isPaused => _isPaused;

  Future<void> pause(Content content) async {
    log('Pausing ${content.contentID}...');
    final taskId = content.contentID;
    if (taskId == null) return;
    final task = await _fileDownloader.taskForId(taskId);

    (task is DownloadTask) ? await FileDownloader().pause(task) : null;
  }

  Future<bool> resume(Content content) async {
    final taskId = content.contentID;
    if (taskId == null) return false;
    final record = await fileDownloader.database.recordForId(taskId);
    final task = record?.task;
    if (task == null) return false;
    final canResume = await _fileDownloader.taskCanResume(task);
    if (!canResume) return false;
    log('Resuming ${content.contentID}...');
    return (task is DownloadTask) ? await FileDownloader().resume(task) : false;
  }

  Future<void> add(Content content) async {
    log('Adding ${content.contentID} to download queue...');

    if (_downloadQueue.contains(content) ||
        _downloadBox.containsKey(content.contentID)) {
      log('${content.contentID} already in queue or downloading.');
      return;
    }

    await _downloadBox.put(
        content.contentID,
        DownloadItem(
          content: content,
          fileSize: content.fileSize ?? 0,
        ));
    _downloadQueue.add(content);
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      while (_activeDownloads < _maxConcurrentDownloads &&
          _downloadQueue.isNotEmpty) {
        final content = _downloadQueue.removeAt(0);
        _activeDownloads++;
        download(content).then((_) {
          _activeDownloads--;
          _startDownload();
        });
      }
    } catch (e) {
      log('Error in _startDownload: $e', error: e);
    }
  }

  Future<void> download(Content content) async {
    final url = content.pkgDirectLink;
    if (url == null) {
      _activeDownloads--;
      return;
    }

    final List<String> downloadsPath = await getDownloadsPath();

    final task = await createDownloadTask(content);

    if (task == null) {
      _activeDownloads--;
      return;
    }

    final record = await fileDownloader.database.recordForId(task.taskId);

    if (record != null) {
      log('Task already exists');
      _activeDownloads--;
    } else {
      fileDownloader.download(
        task,
        onProgress: (progress) {
          log('Progress: ${progress * 100}%');
          final downloadItem = _downloadBox.get(content.contentID) ??
              DownloadItem(
                content: content,
                progress: progress,
                fileSize: content.fileSize ?? 0,
              );
          if (progress < 0) return;
          _downloadBox.put(
              content.contentID, downloadItem.copyWith(progress: progress));
        },
        onStatus: (status) async {
          log('Status: $status');
          final downloadItem = _downloadBox.get(content.contentID) ??
              DownloadItem(
                content: content,
                fileSize: content.fileSize ?? 0,
              );
          DownloadStatus downloadStatus;
          switch (status) {
            case TaskStatus.enqueued:
              downloadStatus = DownloadStatus.enqueued;
              break;
            case TaskStatus.running:
              downloadStatus = DownloadStatus.running;
              break;
            case TaskStatus.paused:
              downloadStatus = DownloadStatus.paused;
              break;
            case TaskStatus.complete:
              downloadStatus = DownloadStatus.complete;
              break;
            case TaskStatus.failed:
              downloadStatus = DownloadStatus.failed;
              break;
            case TaskStatus.notFound:
              downloadStatus = DownloadStatus.notFound;
              break;
            case TaskStatus.waitingToRetry:
              downloadStatus = DownloadStatus.waitingToRetry;
              break;
            case TaskStatus.canceled:
              downloadStatus = DownloadStatus.canceled;
              break;
          }

          _downloadBox.put(
            content.contentID,
            downloadItem.copyWith(downloadStatus: downloadStatus),
          );

          if (status == TaskStatus.complete ||
              status == TaskStatus.failed ||
              status == TaskStatus.notFound ||
              status == TaskStatus.canceled) {
            switch (status) {
              case TaskStatus.complete:
                await extractPkg(content);
                break;
              case TaskStatus.canceled:
                await removeFromQueue(content);
                break;
              default:
                break;
            }
            _activeDownloads--;
            _startDownload();
          }
        },
      ).catchError((error) {
        log('Download failed: $error', error: error);
        _activeDownloads--;
        _startDownload();
      });
    }
  }

  Future<void> removeFromQueue(Content content) async {
    try {
      _downloadQueue.remove(content);
      final taskId = content.contentID;
      await _fileDownloader.cancelTaskWithId(taskId!);
      await _fileDownloader.database.deleteRecordWithId(taskId);
      await _downloadBox.delete(content.contentID);
      if (_downloadBox.isEmpty) {
        await _fileDownloader.database.deleteAllRecords();
      }
    } catch (e) {
      log('Error cancelling download: $e', error: e);
    }
  }
}

Future<DownloadTask?> createDownloadTask(Content content) async {
  final url = content.pkgDirectLink;
  if (url == null) {
    return null;
  }

  final List<String> downloadsPath = await getDownloadsPath();
  final String filename = '${content.contentID}.pkg';
  final List<String> directory = [...downloadsPath, content.titleID];

  final task = DownloadTask(
    taskId: content.contentID,
    url: url,
    filename: filename,
    baseDirectory: BaseDirectory.root,
    directory: pathJoin(directory),
    updates: Updates.statusAndProgress,
    retries: 5,
    allowPause: true,
  );

  return task;
}
