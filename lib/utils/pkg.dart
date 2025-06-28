import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';

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
    logger('pkg2zip output: $line');
  });

  process.stderr.transform(utf8.decoder).forEach((line) {
    logger('pkg2zip error: $line');
  });

  var exitCode = await process.exitCode;

  return exitCode == 0 ? pkgName : null;
}

Future<bool> pkg2zip({
  required List<String> path,
  String? zRIF,
  bool? extract,
  bool? delete,
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

  process.stdout.transform(utf8.decoder).listen((line) {
    logger('pkg2zip output: $line');
  });

  process.stderr.transform(utf8.decoder).listen((line) {
    logger('pkg2zip error: $line');
  });

  var exitCode = await process.exitCode;

  if (delete == true && exitCode == 0) {
    final file = File(pathJoin(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

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
    logger('File copied to: $path');
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
  logger('chmod exit code: ${chmodResult.exitCode}');

  return chmodResult.exitCode == 0;
}
