import 'dart:convert';
import 'dart:io';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';

Future<String?> getPkgName(List<String> path) async {
  final List<String> pkg2zipPath = await getPkg2zipPath();
  final List<String> workingPath = path.sublist(0, path.length - 1);

  logger('pkg2zip path: ${pathJoin(pkg2zipPath)}');
  logger('pkg path: ${pathJoin(path)}');

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
}) async {
  final List<String> pkg2zipPath = await getPkg2zipPath();
  final List<String> workingPath = path.sublist(0, path.length - 1);

  var process = await Process.start(
    pathJoin(pkg2zipPath),
    [if (extract == true) '-x', pathJoin(path), if (zRIF != null) zRIF],
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

  return exitCode == 0;
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
