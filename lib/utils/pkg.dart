import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:vita_dl/utils/storage.dart';

Future<String?> getPkgZipName(String path) async {
  final pkg2zipPath = await getPkg2zipPath();
  final workingPath = path.substring(0, path.lastIndexOf('/'));

  final process = await Process.start(
    pkg2zipPath,
    ['-l', path],
    runInShell: true,
    workingDirectory: workingPath,
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
  required String path,
  String? zRIF,
  bool? extract,
}) async {
  final pkg2zipPath = await getPkg2zipPath();
  final workingPath = path.substring(0, path.lastIndexOf('/'));

  var process = await Process.start(
    pkg2zipPath,
    [
      if (extract != null) '-x',
      path,
      if (zRIF != null) zRIF,
    ],
    runInShell: true,
    workingDirectory: workingPath,
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

Future<void> copyPkg2zip(String path) async {
  const aarch64SourcePath = 'assets/pkg2zip-linux-aarch64/pkg2zip';
  const windowsX64SourcePath = 'assets/pkg2zip-windows-x64/pkg2zip.exe';

  final sourcePath =
      Platform.isWindows ? windowsX64SourcePath : aarch64SourcePath;

  final file = File(path);
  if (!await file.exists()) {
    final byteData = await rootBundle.load(sourcePath);
    final buffer = byteData.buffer.asUint8List();
    await file.writeAsBytes(buffer);
    log('File copied to: $path');
  }
}

Future<bool> chmodPkg2zip(String path) async {
  final workingPath = path.substring(0, path.lastIndexOf('/'));
  var chmodResult = await Process.run(
    'chmod',
    ['+x', path],
    runInShell: true,
    workingDirectory: workingPath,
  );
  log('chmod exit code: ${chmodResult.exitCode}');

  return chmodResult.exitCode == 0;
}
