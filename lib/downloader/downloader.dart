import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'package:vita_dl/downloader/create_download_item.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/utils/logger.dart';
import 'package:vita_dl/utils/path.dart';
import 'package:vita_dl/utils/pkg.dart';

class Downloader {
  Downloader._privateConstructor();

  static final Downloader _instance = Downloader._privateConstructor();

  static Downloader get instance => _instance;

  final dio = Dio();

  Box<DownloadItem> downloadBox = Hive.box<DownloadItem>(downloadBoxName);

  final Queue<Content> _queue = Queue();
  final Map<String, CancelToken> cancelTokens = {};
  int maxConcurrentTasks = 2;
  int runningTasks = 0;

  static const partialExtension = ".partial";
  static const tempExtension = ".temp";

  Future<void> init() async {
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 60);

    final downloads = downloadBox.values.toList();
    for (final download in downloads) {
      if ([DownloadStatus.downloading, DownloadStatus.queued]
          .contains(download.downloadStatus)) {
        downloadBox.put(
          download.key,
          download.copyWith(downloadStatus: DownloadStatus.paused),
        );
      }
    }
  }

  Future<void> add(Content content) async {
    final downloadItem = await createDownloadItem(content);
    final id = content.getID();
    if (downloadItem == null || id == null) return;

    if (downloadItem.downloadStatus == DownloadStatus.downloading ||
        _queue.contains(content)) {
      logger('Already downloading $id...');
      return;
    }

    logger('Adding $id to download queue...');
    await downloadBox.put(downloadItem.id, downloadItem);
    _queue.add(content);
    _start();
  }

  Future<void> _start() async {
    try {
      while (runningTasks < maxConcurrentTasks && _queue.isNotEmpty) {
        final content = _queue.removeFirst();
        runningTasks++;
        download(content).then((_) {
          runningTasks--;
          _start();
        });
      }
    } catch (e) {
      logger('Error in _start: $e');
    }
  }

  Future<void> pause(Content content) async {
    final downloadItem = downloadBox.get(content.getID());
    final id = downloadItem?.id;
    if (downloadItem == null || id == null) return;

    logger('Pausing $id (Dio: set status to paused)...');
    downloadBox.put(
      downloadItem.id,
      downloadItem.copyWith(downloadStatus: DownloadStatus.paused),
    );
    final cancelToken = cancelTokens[id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Download paused');
    }
    if (_queue.contains(content)) {
      _queue.remove(content);
    }
  }

  Future<bool> resume(Content content) async {
    final downloadItem = downloadBox.get(content.getID());
    final id = downloadItem?.id;
    if (downloadItem == null ||
        id == null ||
        downloadItem.downloadStatus == DownloadStatus.downloading) {
      return false;
    }
    if (_queue.contains(content)) {
      return true;
    }

    logger('Resuming $id...');
    add(content);
    return true;
  }

  Future<void> remove(Content content) async {
    try {
      await pause(content);
      await downloadBox.delete(content.getID());
      logger('Removed ${content.getID()} from download queue...');
    } catch (e) {
      logger('Error cancelling download: $e');
    }
  }

  Future<void> download(Content content) async {
    final String? url = content.pkgDirectLink;
    if (url == null) return;

    late String partialFilePath;
    late File partialFile;

    try {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      final id = downloadItem?.id;
      if (downloadItem == null || id == null) return;

      CancelToken cancelToken = CancelToken();
      cancelTokens[id] = cancelToken;

      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.downloading),
      );

      final String filePath =
          pathJoin([...downloadItem.directory, downloadItem.filename]);
      File file = File(filePath);
      partialFilePath =
          pathJoin([...downloadItem.directory, downloadItem.filename]) +
              partialExtension;
      partialFile = File(partialFilePath);

      var fileExist = await file.exists();
      var partialFileExist = await partialFile.exists();

      if (fileExist) {
        logger("File Exists");
        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(
            progress: 1,
            downloadStatus: DownloadStatus.completed,
          ),
        );
      } else if (partialFileExist) {
        logger("Partial File Exists");

        var partialFileLength = await partialFile.length();

        var response = await dio.download(
          url,
          partialFilePath + tempExtension,
          onReceiveProgress: onReceiveCallback(content, partialFileLength),
          options: Options(
            headers: {HttpHeaders.rangeHeader: 'bytes=$partialFileLength-'},
          ),
          cancelToken: cancelToken,
          deleteOnError: true,
        );

        if (response.statusCode == HttpStatus.partialContent) {
          var ioSink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);
          var f = File(partialFilePath + tempExtension);
          await ioSink.addStream(f.openRead());
          await f.delete();
          await ioSink.close();
          await partialFile.rename(filePath);

          downloadBox.put(
            downloadItem.id,
            downloadItem.copyWith(
              progress: 1,
              downloadStatus: DownloadStatus.completed,
            ),
          );
        }
      } else {
        var response = await dio.download(
          url,
          partialFilePath,
          onReceiveProgress: onReceiveCallback(content, 0),
          cancelToken: cancelToken,
          deleteOnError: false,
        );

        if (response.statusCode == HttpStatus.ok) {
          await partialFile.rename(filePath);
          downloadBox.put(
            downloadItem.id,
            downloadItem.copyWith(
              progress: 1,
              downloadStatus: DownloadStatus.completed,
            ),
          );
        }
      }
    } catch (e) {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      if (downloadItem!.downloadStatus != DownloadStatus.canceled &&
          downloadItem.downloadStatus != DownloadStatus.paused) {
        logger('Downloading failed ${content.getID()}', error: e);
        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(downloadStatus: DownloadStatus.failed),
        );
        runningTasks--;

        if (_queue.isNotEmpty) {
          _start();
        }
      } else if (downloadItem.downloadStatus == DownloadStatus.paused) {
        final ioSink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);
        final f = File(partialFilePath + tempExtension);
        if (await f.exists()) {
          await ioSink.addStream(f.openRead());
        }
        await ioSink.close();
      }
    } finally {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      if (downloadItem != null &&
          downloadItem.downloadStatus == DownloadStatus.completed) {
        final List<String> path = [
          ...downloadItem.directory,
          downloadItem.filename
        ];

        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(
            extractStatus: ExtractStatus.extracting,
          ),
        );

        try {
          final pkgName = await getPkgName(path);
          logger('pkgName: $pkgName');
        } catch (e) {
          logger('getPkgName failed:', error: e);
        }

        final result = await pkg2zip(
          path: path,
          extract: content.type == ContentType.theme ? false : true,
          zRIF: content.zRIF,
        );

        if (result) {
          downloadBox.put(
            downloadItem.id,
            downloadItem.copyWith(
              extractStatus: ExtractStatus.completed,
            ),
          );
        } else {
          downloadBox.put(
            downloadItem.id,
            downloadItem.copyWith(
              extractStatus: ExtractStatus.failed,
            ),
          );
        }
      }
    }

    runningTasks--;

    if (_queue.isNotEmpty) {
      _start();
    }
  }

  void Function(int, int) onReceiveCallback(
    Content content,
    int partialFileLength,
  ) =>
      (
        int received,
        int total,
      ) {
        DownloadItem? downloadItem = downloadBox.get(content.getID());
        if (downloadItem == null) return;

        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(
            downloadStatus: DownloadStatus.downloading,
            progress:
                (received + partialFileLength) / (total + partialFileLength),
            size: total + partialFileLength,
          ),
        );

        if (total == -1) {}
      };
}
