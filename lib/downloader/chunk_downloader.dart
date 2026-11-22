import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:fnps/utils/my_http_overrides.dart';

enum ChunkDownloadStatus { completed, paused, canceled, failed }

class ChunkDownloadResult {
  final ChunkDownloadStatus status;
  final int totalLength;
  final int completedLength;
  final String? errorMessage;

  const ChunkDownloadResult({
    required this.status,
    required this.totalLength,
    required this.completedLength,
    this.errorMessage,
  });
}

typedef DownloadProgressCallback =
    void Function(int completedLength, int totalLength);

class ChunkDownloadTask {
  final String url;
  final String savePath;
  final int connections;
  final int minChunkSize;

  SendPort? _controlPort;
  bool _pauseRequested = false;
  bool _cancelRequested = false;
  bool _finished = false;

  ChunkDownloadTask({
    required this.url,
    required this.savePath,
    this.connections = 12,
    this.minChunkSize = 4 * 1024 * 1024,
  });

  Future<ChunkDownloadResult> start({
    required DownloadProgressCallback onProgress,
  }) async {
    final ReceivePort messagePort = ReceivePort();
    final ReceivePort errorPort = ReceivePort();
    final ReceivePort exitPort = ReceivePort();
    final Completer<ChunkDownloadResult> completer =
        Completer<ChunkDownloadResult>();

    int lastTotal = 0;
    int lastCompleted = 0;

    void finish(ChunkDownloadResult result) {
      if (completer.isCompleted) return;
      _finished = true;
      messagePort.close();
      errorPort.close();
      exitPort.close();
      completer.complete(result);
    }

    messagePort.listen((dynamic message) {
      if (message is! Map<String, dynamic>) return;
      final String? type = message['type'] as String?;

      if (type == 'control') {
        _controlPort = message['port'] as SendPort?;
        if (_cancelRequested) {
          _controlPort?.send('cancel');
        } else if (_pauseRequested) {
          _controlPort?.send('pause');
        }
      } else if (type == 'progress') {
        lastCompleted = message['completed'] as int;
        lastTotal = message['total'] as int;
        onProgress(lastCompleted, lastTotal);
      } else if (type == 'done') {
        final String statusName =
            message['status'] as String? ?? ChunkDownloadStatus.failed.name;
        final ChunkDownloadStatus status = ChunkDownloadStatus.values.firstWhere(
          (e) => e.name == statusName,
          orElse: () => ChunkDownloadStatus.failed,
        );
        finish(
          ChunkDownloadResult(
            status: status,
            totalLength: message['total'] as int? ?? lastTotal,
            completedLength: message['completed'] as int? ?? lastCompleted,
            errorMessage: message['error'] as String?,
          ),
        );
      }
    });

    errorPort.listen((dynamic error) {
      finish(
        ChunkDownloadResult(
          status: _cancelRequested
              ? ChunkDownloadStatus.canceled
              : _pauseRequested
              ? ChunkDownloadStatus.paused
              : ChunkDownloadStatus.failed,
          totalLength: lastTotal,
          completedLength: lastCompleted,
          errorMessage: error.toString(),
        ),
      );
    });

    exitPort.listen((dynamic _) {
      if (!completer.isCompleted) {
        finish(
          ChunkDownloadResult(
            status: _cancelRequested
                ? ChunkDownloadStatus.canceled
                : _pauseRequested
                ? ChunkDownloadStatus.paused
                : ChunkDownloadStatus.failed,
            totalLength: lastTotal,
            completedLength: lastCompleted,
            errorMessage: 'Download isolate exited unexpectedly',
          ),
        );
      }
    });

    try {
      await Isolate.spawn<_WorkerConfig>(
        _workerEntry,
        _WorkerConfig(
          replyPort: messagePort.sendPort,
          url: url,
          savePath: savePath,
          connections: connections,
          minChunkSize: minChunkSize,
        ),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );
    } catch (e) {
      finish(
        ChunkDownloadResult(
          status: ChunkDownloadStatus.failed,
          totalLength: 0,
          completedLength: 0,
          errorMessage: e.toString(),
        ),
      );
    }

    return completer.future;
  }

  void pause() {
    if (_finished || _cancelRequested) return;
    _pauseRequested = true;
    _controlPort?.send('pause');
  }

  void cancel() {
    if (_finished) return;
    _cancelRequested = true;
    _controlPort?.send('cancel');
  }

  static Future<void> cleanupTempFiles(String savePath) async {
    final File saveFile = File(savePath);
    final Directory dir = saveFile.parent;
    final String baseName = saveFile.uri.pathSegments.last;

    if (!await dir.exists()) return;

    await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.last;
      if (name == '$baseName.meta' ||
          name == '$baseName.merging' ||
          name == '$baseName.part' ||
          name == '$baseName.aria2' ||
          name.startsWith('$baseName.part.')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }
}

class _WorkerConfig {
  final SendPort replyPort;
  final String url;
  final String savePath;
  final int connections;
  final int minChunkSize;

  const _WorkerConfig({
    required this.replyPort,
    required this.url,
    required this.savePath,
    required this.connections,
    required this.minChunkSize,
  });
}

class _ProbeResult {
  final int totalLength;
  final bool supportsRange;

  const _ProbeResult({required this.totalLength, required this.supportsRange});
}

class _Segment {
  final int index;
  final int start;
  final int end;

  const _Segment({required this.index, required this.start, required this.end});

  int get length => end - start + 1;
}

Future<void> _workerEntry(_WorkerConfig config) async {
  HttpOverrides.global = MyHttpOverrides();

  final ReceivePort controlPort = ReceivePort();
  config.replyPort.send(<String, dynamic>{
    'type': 'control',
    'port': controlPort.sendPort,
  });

  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = config.connections + 2;

  bool stopped = false;
  bool isCancel = false;

  final StreamSubscription<dynamic> controlSub = controlPort.listen((
    dynamic msg,
  ) {
    if (msg == 'pause') {
      stopped = true;
      client.close(force: true);
    } else if (msg == 'cancel') {
      stopped = true;
      isCancel = true;
      client.close(force: true);
    }
  });

  int totalLength = 0;
  int completedBytes = 0;
  DateTime lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  void emitProgress({bool force = false}) {
    final DateTime now = DateTime.now();
    if (!force && now.difference(lastEmit).inMilliseconds < 300) {
      return;
    }
    lastEmit = now;
    config.replyPort.send(<String, dynamic>{
      'type': 'progress',
      'completed': completedBytes,
      'total': totalLength,
    });
  }

  ChunkDownloadStatus status = ChunkDownloadStatus.failed;
  String? errorMessage;

  try {
    final File targetFile = File(config.savePath);
    await targetFile.parent.create(recursive: true);

    final _ProbeResult probe = await _probeUrl(
      client: client,
      url: config.url,
      isStopped: () => stopped,
    );

    if (stopped) {
      status = isCancel
          ? ChunkDownloadStatus.canceled
          : ChunkDownloadStatus.paused;
    } else {
      totalLength = probe.totalLength;

      if (await targetFile.exists() &&
          totalLength > 0 &&
          await targetFile.length() == totalLength) {
        completedBytes = totalLength;
        emitProgress(force: true);
        status = ChunkDownloadStatus.completed;
      } else if (!probe.supportsRange ||
          totalLength <= 0 ||
          totalLength < config.minChunkSize * 2) {
        final bool ok = await _downloadSingleStream(
          client: client,
          config: config,
          supportsRange: probe.supportsRange,
          totalLength: totalLength,
          isStopped: () => stopped,
          onBytes: (int completed, int total) {
            completedBytes = completed;
            if (total > 0) totalLength = total;
            emitProgress();
          },
        );

        if (stopped) {
          status = isCancel
              ? ChunkDownloadStatus.canceled
              : ChunkDownloadStatus.paused;
        } else if (ok) {
          emitProgress(force: true);
          status = ChunkDownloadStatus.completed;
        }
      } else {
        final bool ok = await _downloadMultiSegment(
          client: client,
          config: config,
          totalLength: totalLength,
          isStopped: () => stopped,
          onInitialBytes: (int initial) {
            completedBytes = initial;
            emitProgress(force: true);
          },
          onDeltaBytes: (int delta) {
            completedBytes += delta;
            emitProgress();
          },
        );

        if (stopped) {
          status = isCancel
              ? ChunkDownloadStatus.canceled
              : ChunkDownloadStatus.paused;
        } else if (ok) {
          completedBytes = totalLength;
          emitProgress(force: true);
          status = ChunkDownloadStatus.completed;
        }
      }
    }
  } catch (e) {
    if (stopped) {
      status = isCancel
          ? ChunkDownloadStatus.canceled
          : ChunkDownloadStatus.paused;
    } else {
      status = ChunkDownloadStatus.failed;
      errorMessage = e.toString();
    }
  } finally {
    if (isCancel) {
      await ChunkDownloadTask.cleanupTempFiles(config.savePath);
    }
    await controlSub.cancel();
    controlPort.close();
    try {
      client.close(force: true);
    } catch (_) {}
  }

  config.replyPort.send(<String, dynamic>{
    'type': 'done',
    'status': status.name,
    'total': totalLength,
    'completed': completedBytes,
    'error': errorMessage,
  });
}

Future<_ProbeResult> _probeUrl({
  required HttpClient client,
  required String url,
  required bool Function() isStopped,
}) async {
  Object? lastError;
  for (int attempt = 0; attempt < 3; attempt++) {
    if (isStopped()) {
      return const _ProbeResult(totalLength: 0, supportsRange: false);
    }
    try {
      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
      final HttpClientResponse res = await req.close();
      await res.drain<void>();

      if (res.statusCode == HttpStatus.partialContent) {
        final String? contentRange = res.headers.value(
          HttpHeaders.contentRangeHeader,
        );
        final int total = _parseContentRangeTotal(contentRange);
        return _ProbeResult(totalLength: total, supportsRange: total > 0);
      }

      if (res.statusCode == HttpStatus.ok) {
        final int total = res.contentLength > 0 ? res.contentLength : 0;
        final bool acceptBytes =
            res.headers.value(HttpHeaders.acceptRangesHeader)?.toLowerCase() ==
            'bytes';
        return _ProbeResult(
          totalLength: total,
          supportsRange: acceptBytes && total > 0,
        );
      }

      lastError = HttpException('Unexpected probe status: ${res.statusCode}');
    } catch (e) {
      lastError = e;
    }
    await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
  }
  throw lastError ?? Exception('Failed to probe URL');
}

int _parseContentRangeTotal(String? header) {
  if (header == null) return 0;
  final int slashIndex = header.lastIndexOf('/');
  if (slashIndex == -1 || slashIndex == header.length - 1) return 0;
  final String totalStr = header.substring(slashIndex + 1).trim();
  if (totalStr == '*') return 0;
  return int.tryParse(totalStr) ?? 0;
}

Future<bool> _downloadSingleStream({
  required HttpClient client,
  required _WorkerConfig config,
  required bool supportsRange,
  required int totalLength,
  required bool Function() isStopped,
  required void Function(int completed, int total) onBytes,
}) async {
  final File partFile = File('${config.savePath}.part');
  int existing = 0;
  if (supportsRange && await partFile.exists()) {
    existing = await partFile.length();
    if (totalLength > 0 && existing > totalLength) {
      await partFile.delete();
      existing = 0;
    }
  }

  final HttpClientRequest req = await client.getUrl(Uri.parse(config.url));
  if (supportsRange && existing > 0) {
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=$existing-');
  }
  final HttpClientResponse res = await req.close();

  final bool resuming =
      supportsRange && existing > 0 && res.statusCode == HttpStatus.partialContent;
  if (!resuming && res.statusCode != HttpStatus.ok) {
    await res.drain<void>();
    throw HttpException('HTTP ${res.statusCode}');
  }

  final int resolvedTotal = totalLength > 0
      ? totalLength
      : (res.contentLength > 0 ? res.contentLength : 0);

  int completed = resuming ? existing : 0;
  final RandomAccessFile raf = await partFile.open(
    mode: resuming ? FileMode.writeOnlyAppend : FileMode.write,
  );

  try {
    await for (final List<int> chunk in res) {
      if (isStopped()) break;
      await raf.writeFrom(chunk);
      completed += chunk.length;
      onBytes(completed, resolvedTotal);
    }
    await raf.flush();
  } finally {
    await raf.close();
  }

  if (isStopped()) return false;
  if (resolvedTotal > 0 && completed < resolvedTotal) {
    throw const HttpException('Incomplete single-stream download');
  }

  final File targetFile = File(config.savePath);
  if (await targetFile.exists()) {
    await targetFile.delete();
  }
  await partFile.rename(config.savePath);
  return true;
}

Future<bool> _downloadMultiSegment({
  required HttpClient client,
  required _WorkerConfig config,
  required int totalLength,
  required bool Function() isStopped,
  required void Function(int initial) onInitialBytes,
  required void Function(int delta) onDeltaBytes,
}) async {
  final int maxSegments = (totalLength / config.minChunkSize).ceil();
  final int segmentCount = min(config.connections * 2, maxSegments).clamp(1, 24);
  final File metaFile = File('${config.savePath}.meta');

  bool canResume = false;
  if (await metaFile.exists()) {
    try {
      final Map<String, dynamic> meta =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      if (meta['totalLength'] == totalLength &&
          meta['segmentCount'] == segmentCount) {
        canResume = true;
      }
    } catch (_) {}
  }

  if (!canResume) {
    await ChunkDownloadTask.cleanupTempFiles(config.savePath);
    await metaFile.writeAsString(
      jsonEncode(<String, dynamic>{
        'totalLength': totalLength,
        'segmentCount': segmentCount,
      }),
    );
  }

  final List<_Segment> segments = _buildSegments(totalLength, segmentCount);

  int initialBytes = 0;
  for (final _Segment seg in segments) {
    final File partFile = File('${config.savePath}.part.${seg.index}');
    if (await partFile.exists()) {
      final int len = await partFile.length();
      if (len > seg.length) {
        await partFile.delete();
      } else {
        initialBytes += len;
      }
    }
  }
  onInitialBytes(initialBytes);

  int nextSegmentIdx = 0;
  Object? workerError;

  Future<void> runWorker() async {
    while (!isStopped() && workerError == null) {
      if (nextSegmentIdx >= segments.length) return;
      final _Segment seg = segments[nextSegmentIdx++];
      try {
        await _downloadSegmentWithRetry(
          client: client,
          url: config.url,
          partPath: '${config.savePath}.part.${seg.index}',
          segment: seg,
          isStopped: isStopped,
          onDeltaBytes: onDeltaBytes,
        );
      } catch (e) {
        if (!isStopped()) {
          workerError ??= e;
        }
        return;
      }
    }
  }

  final int workerCount = min(config.connections, segmentCount);
  await Future.wait(
    List<Future<void>>.generate(workerCount, (_) => runWorker()),
  );

  if (isStopped()) return false;
  if (workerError != null) throw workerError!;

  await _mergeSegments(config.savePath, segmentCount, isStopped);
  if (isStopped()) return false;

  if (await metaFile.exists()) {
    await metaFile.delete();
  }
  return true;
}

List<_Segment> _buildSegments(int totalLength, int segmentCount) {
  final int baseSize = totalLength ~/ segmentCount;
  final int remainder = totalLength % segmentCount;
  final List<_Segment> segments = <_Segment>[];

  int offset = 0;
  for (int i = 0; i < segmentCount; i++) {
    final int size = baseSize + (i < remainder ? 1 : 0);
    segments.add(_Segment(index: i, start: offset, end: offset + size - 1));
    offset += size;
  }
  return segments;
}

Future<void> _downloadSegmentWithRetry({
  required HttpClient client,
  required String url,
  required String partPath,
  required _Segment segment,
  required bool Function() isStopped,
  required void Function(int delta) onDeltaBytes,
}) async {
  Object? lastError;

  for (int attempt = 0; attempt < 5; attempt++) {
    if (isStopped()) return;

    final File partFile = File(partPath);
    final int existing = await partFile.exists() ? await partFile.length() : 0;
    if (existing >= segment.length) return;

    final int rangeStart = segment.start + existing;
    RandomAccessFile? raf;

    try {
      final HttpClientRequest req = await client.getUrl(Uri.parse(url));
      req.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=$rangeStart-${segment.end}',
      );
      final HttpClientResponse res = await req.close();

      if (res.statusCode != HttpStatus.partialContent &&
          !(existing == 0 && res.statusCode == HttpStatus.ok)) {
        await res.drain<void>();
        throw HttpException('Segment ${segment.index} HTTP ${res.statusCode}');
      }

      raf = await partFile.open(mode: FileMode.writeOnlyAppend);
      await for (final List<int> chunk in res) {
        if (isStopped()) break;
        await raf.writeFrom(chunk);
        onDeltaBytes(chunk.length);
      }
      await raf.flush();
      await raf.close();
      raf = null;

      if (isStopped()) return;

      final int downloaded = await partFile.length();
      if (downloaded >= segment.length) {
        return;
      }
      lastError = HttpException(
        'Segment ${segment.index} incomplete ($downloaded/${segment.length})',
      );
    } catch (e) {
      lastError = e;
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }
      if (isStopped()) return;
    }

    await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
  }

  throw lastError ?? Exception('Segment ${segment.index} failed');
}

Future<void> _mergeSegments(
  String savePath,
  int segmentCount,
  bool Function() isStopped,
) async {
  final File mergingFile = File('$savePath.merging');
  if (await mergingFile.exists()) {
    await mergingFile.delete();
  }

  final File firstPart = File('$savePath.part.0');
  await firstPart.rename(mergingFile.path);

  final RandomAccessFile outRaf = await mergingFile.open(
    mode: FileMode.writeOnlyAppend,
  );
  try {
    for (int i = 1; i < segmentCount; i++) {
      if (isStopped()) return;
      final File part = File('$savePath.part.$i');
      await for (final List<int> chunk in part.openRead()) {
        if (isStopped()) return;
        await outRaf.writeFrom(chunk);
      }
      await outRaf.flush();
      await part.delete();
    }
  } finally {
    await outRaf.close();
  }

  if (isStopped()) return;

  final File targetFile = File(savePath);
  if (await targetFile.exists()) {
    await targetFile.delete();
  }
  await mergingFile.rename(savePath);
}
