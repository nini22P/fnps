import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vita_dl/utils/pkg.dart';

Future<String> getAppPath() async {
  final directory = Platform.isAndroid
      ? await getExternalStorageDirectory()
      : await getApplicationDocumentsDirectory();
  return join('${directory?.path}/VitaDL');
}

Future<String> getDownloadsPath() async {
  final appPath = await getAppPath();
  final path = join('$appPath/downloads');
  if (!await Directory(path).exists()) {
    await Directory(path).create(recursive: true);
  }
  return path;
}

Future<String> getPkg2zipPath() async {
  final appDocPath = (await getApplicationDocumentsDirectory()).path;
  final appPath = await getAppPath();
  final targetFolder = Platform.isAndroid ? appDocPath : appPath;
  final path = Platform.isWindows
      ? '$targetFolder/pkg2zip.exe'
      : '$targetFolder/pkg2zip';
  final file = File(path);
  if (!await file.exists()) {
    await copyPkg2zip(path);
    if (!Platform.isWindows) {
      await chmodPkg2zip(path);
    }
  }
  return path;
}
