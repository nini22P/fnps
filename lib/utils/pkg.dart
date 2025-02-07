import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/utils/path.dart';

Future<String?> getPkgName(List<String> path) async {
  final List<String> pkg2zipPath = await getPkg2zipPath();
  final List<String> workingPath = path.sublist(0, path.length - 1);

  final process = await Process.start(
    pathJoin(pkg2zipPath),
    ['-l', pathJoin(path)],
    runInShell: true,
    workingDirectory: pathJoin(workingPath),
  );

  String? pkgName;
  process.stdout.transform(utf8.decoder).forEach((line) {
    pkgName = line;
    log('pkg2zip output: $line');
  });

  process.stderr.transform(utf8.decoder).forEach((line) {
    log('pkg2zip error: $line');
  });

  var exitCode = await process.exitCode;

  return exitCode == 0 ? pkgName : null;
}

Future<bool> pkg2zip({
  required List<String> path,
  String? zRIF,
  bool? extract,
}) async {
  final List<String> pkg2zipPath = await getPkg2zipPath();
  final List<String> workingPath = path.sublist(0, path.length - 1);

  var process = await Process.start(
    pathJoin(pkg2zipPath),
    [
      if (extract == true) '-x',
      pathJoin(path),
      if (zRIF != null) zRIF,
    ],
    runInShell: true,
    workingDirectory: pathJoin(workingPath),
  );

  process.stdout.transform(utf8.decoder).forEach((line) {
    log('pkg2zip output: $line');
  });

  process.stderr.transform(utf8.decoder).forEach((line) {
    log('pkg2zip error: $line');
  });

  var exitCode = await process.exitCode;

  return exitCode == 0;
}

Future<void> copyPkg2zip(List<String> path) async {
  const aarch64SourcePath = 'assets/pkg2zip-linux-aarch64/pkg2zip';
  const windowsX64SourcePath = 'assets/pkg2zip-windows-x64/pkg2zip.exe';

  final sourcePath =
      Platform.isWindows ? windowsX64SourcePath : aarch64SourcePath;

  final file = File(pathJoin(path));
  if (!await file.exists()) {
    final byteData = await rootBundle.load(sourcePath);
    final buffer = byteData.buffer.asUint8List();
    await file.writeAsBytes(buffer);
    log('File copied to: $path');
  }
}

Future<bool> chmodPkg2zip(List<String> path) async {
  final workingPath = path.sublist(0, path.length - 1);
  var chmodResult = await Process.run(
    'chmod',
    ['+x', pathJoin(path)],
    runInShell: true,
    workingDirectory: pathJoin(workingPath),
  );
  log('chmod exit code: ${chmodResult.exitCode}');

  return chmodResult.exitCode == 0;
}

Future<bool> extractPkg(Content content) async {
  final downloadBox = Hive.box<DownloadItem>(downloadBoxName);
  final downloadItem = downloadBox.get(content.contentID);

  if (downloadItem == null) return false;

  try {
    final List<String> path = [...downloadItem.directory, downloadItem.name];

    String? pkgName;
    try {
      pkgName = await getPkgName(path);
      log('pkgName: $pkgName');
    } catch (e) {
      log('getPkgName failed: $e', error: e);
      downloadBox.put(
        content.contentID,
        downloadItem.copyWith(extractStatus: ExtractStatus.failed),
      );
      return false;
    }

    downloadBox.put(
      content.contentID,
      downloadItem.copyWith(
        extractStatus: ExtractStatus.extracting,
      ),
    );

    final result = await pkg2zip(
      path: path,
      extract: content.type == ContentType.theme ? false : true,
      zRIF: content.zRIF,
    );

    if (result) {
      log('pkg2zip success');
      downloadBox.put(
        content.contentID,
        downloadItem.copyWith(extractStatus: ExtractStatus.completed),
      );
      return true;
    } else {
      log('pkg2zip failed');
      downloadBox.put(
        content.contentID,
        downloadItem.copyWith(extractStatus: ExtractStatus.failed),
      );
      return false;
    }
  } catch (e) {
    log('pkg2zip error: $e', error: e);
    downloadBox.put(
      content.contentID,
      downloadItem.copyWith(extractStatus: ExtractStatus.failed),
    );
    return false;
  }
}
