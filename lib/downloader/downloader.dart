import 'dart:collection';
import 'dart:io';
import 'package:dio/dio.dart';
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

  final dio = Dio();

  Box<DownloadItem> downloadBox = Hive.box<DownloadItem>(downloadBoxName);

  final Queue<Content> _queue = Queue();
  final Map<String, CancelToken> cancelTokens = {};
  int maxConcurrentTasks = 3;
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
          download.id,
          download.copyWith(downloadStatus: DownloadStatus.paused),
        );
      } else if (download.downloadStatus == DownloadStatus.completed &&
          download.extractStatus != ExtractStatus.completed) {
        downloadBox.put(
          download.id,
          download.copyWith(extractStatus: ExtractStatus.failed),
        );
      }
    }
  }

  Future<void> add(List<Content> contents) async {
    for (final content in contents) {
      final downloadItem = await createDownloadItem(content);
      final id = content.getID();
      if (downloadItem == null || id == null) return;

      if (downloadItem.downloadStatus == DownloadStatus.downloading ||
          _queue.contains(content)) {
        logger('Already downloading $id...');
        continue;
      }

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
            DownloadStatus.failed
          ].contains(downloadItem.downloadStatus)) {
        continue;
      }

      logger('Pausing $id (Dio: set status to paused)...');
      downloadBox.put(
        downloadItem.id,
        downloadItem.copyWith(downloadStatus: DownloadStatus.paused),
      );
      final cancelToken = cancelTokens[id];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download paused');
        runningTasks--;
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

          final String filePath =
              pathJoin([...downloadItem.directory, downloadItem.filename]);
          final String partialFilePath =
              pathJoin([...downloadItem.directory, downloadItem.filename]) +
                  partialExtension;

          File file = File(filePath);
          File partialFile = File(partialFilePath);

          bool fileExist = await file.exists();
          bool partialFileExist = await partialFile.exists();

          try {
            if (fileExist) await file.delete();
          } catch (e) {
            logger('Not delete file: $filePath', error: e);
          }

          try {
            if (partialFileExist) await partialFile.delete();
          } catch (e) {
            logger('Not delete partial file: $filePath', error: e);
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

    late String partialFilePath;
    late File partialFile;

    try {
      DownloadItem? downloadItem = downloadBox.get(content.getID());
      final id = downloadItem?.id;
      if (downloadItem == null || id == null) return;

      CancelToken cancelToken = CancelToken();
      cancelTokens[id] = cancelToken;

      logger('Starting download for ${content.name}');

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

      File tempFile = File(partialFilePath + tempExtension);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      bool fileExist = await file.exists();
      bool partialFileExist = await partialFile.exists();

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

        int partialFileLength = await partialFile.length();

        Response response = await dio.download(
          url,
          partialFilePath + tempExtension,
          onReceiveProgress: onReceiveCallback(content, partialFileLength),
          options: Options(
            headers: {HttpHeaders.rangeHeader: 'bytes=$partialFileLength-'},
          ),
          cancelToken: cancelToken,
          deleteOnError: false,
        );

        if (response.statusCode == HttpStatus.partialContent) {
          IOSink ioSink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);
          File tempFile = File(partialFilePath + tempExtension);
          await ioSink.addStream(tempFile.openRead());
          await tempFile.delete();
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
        Response response = await dio.download(
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
      IOSink ioSink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);
      File tempFile = File(partialFilePath + tempExtension);

      if (await tempFile.exists()) {
        await ioSink.addStream(tempFile.openRead());
        await tempFile.delete();
      }

      await ioSink.close();

      DownloadItem? downloadItem = downloadBox.get(content.getID());
      if (downloadItem!.downloadStatus != DownloadStatus.canceled &&
          downloadItem.downloadStatus != DownloadStatus.paused) {
        logger('Downloading failed ${content.getID()}', error: e);
        downloadBox.put(
          downloadItem.id,
          downloadItem.copyWith(downloadStatus: DownloadStatus.failed),
        );
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
          extract: content.platform == Platform.psv &&
                  content.category == Category.theme
              ? false
              : true,
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
          if (content.platform == Platform.ps3 &&
              content.category != Category.update &&
              content.rap != null &&
              content.rap!.isNotEmpty) {
            await downloadRAP(content);
          }
          downloadBox.put(
            downloadItem.id,
            downloadItem.copyWith(
              extractStatus: content.platform == Platform.ps3
                  ? ExtractStatus.notNeeded
                  : ExtractStatus.failed,
            ),
          );
        }
      }
    }

    runningTasks--;
    _start();
  }

  DateTime? lastUpdateTime;

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

        DateTime now = DateTime.now();

        if (lastUpdateTime != null &&
            now.difference(lastUpdateTime!).inSeconds < 1) {
          return;
        }

        lastUpdateTime = now;

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
