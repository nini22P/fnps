import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:vita_dl/utils/path_conv.dart';
import 'package:vita_dl/utils/pkg.dart';

Future<List<String>> getAppPath() async {
  final directory = Platform.isAndroid
      ? await getExternalStorageDirectory()
      : await getApplicationDocumentsDirectory();
  final path = pathConv(directory!.path);
  return [...path, 'VitaDL'];
}

Future<List<String>> getDownloadsPath() async {
  final appPath = await getAppPath();
  final path = [...appPath, 'downloads'];
  if (!await Directory(pathJoin(path)).exists()) {
    await Directory(pathJoin(path)).create(recursive: true);
  }
  return path;
}

Future<List<String>> getPkg2zipPath() async {
  final appDocPath = pathConv((await getApplicationDocumentsDirectory()).path);
  final appPath = await getAppPath();
  final targetFolder = Platform.isAndroid ? appDocPath : appPath;
  final path = Platform.isWindows
      ? [...targetFolder, 'pkg2zip.exe']
      : [...targetFolder, 'pkg2zip'];
  final file = File(pathJoin(path));
  if (!await file.exists()) {
    await copyPkg2zip(path);
    if (!Platform.isWindows) {
      await chmodPkg2zip(path);
    }
  }
  return path;
}

String pathJoin(List<String> path) =>
    (!Platform.isWindows ? '/' : '') + path.join('/');
