import 'dart:io';
import 'package:android_x_storage/android_x_storage.dart';
import 'package:fnps/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fnps/utils/get_native_library_dir.dart';
import 'package:fnps/utils/platform.dart';
import 'package:fnps/utils/path_conv.dart';
import 'package:path/path.dart' as p;

Future<List<String>> getAppPath() async {
  if (isAndroid) {
    await getExternalStorageDirectory();
  }

  final String dir = isDesktop
      ? await getExecutableDirPath()
      : (await getExternalStorageDirectory())!.path;
  final path = pathConv(dir);
  return [...path, 'FNPS'];
}

Future<String> getExecutableDirPath() async {
  String resolvedExecutablePath = Platform.resolvedExecutable;
  return p.dirname(resolvedExecutablePath);
}

Future<List<String>> getConfigPath() async => [...await getAppPath(), 'config'];

Future<List<String>> getDownloadsPath() async {
  final appPath = await getAppPath();
  String? androidDownloadsPath;
  if (Platform.isAndroid) {
    androidDownloadsPath = await AndroidXStorage().getDownloadsDirectory();
  }

  final path = androidDownloadsPath != null
      ? [...pathConv(androidDownloadsPath), 'FNPS']
      : [...appPath, 'downloads'];

  if (!await Directory(pathJoin(path)).exists()) {
    await Directory(pathJoin(path)).create(recursive: true);
  }
  return path;
}

Future<List<String>> getPkg2zipPath() async {
  final nativeLibraryPath = pathConv(await getNativeLibraryDir() ?? '');
  final executableDirPath = pathConv(await getExecutableDirPath());
  final targetFolder = Platform.isAndroid
      ? nativeLibraryPath
      : executableDirPath;
  final path = Platform.isAndroid
      ? [...targetFolder, 'libpkg2zip.so']
      : Platform.isWindows
      ? [...targetFolder, 'pkg2zip.exe']
      : [...targetFolder, 'pkg2zip'];
  final file = File(pathJoin(path));
  if (!(await file.exists())) {
    logger('Not found pkg2zip at $path');
  }
  return path;
}

Future<List<String>> getAria2cPath() async {
  final nativeLibraryPath = pathConv(await getNativeLibraryDir() ?? '');
  final executableDirPath = pathConv(await getExecutableDirPath());
  final targetFolder = Platform.isAndroid
      ? nativeLibraryPath
      : executableDirPath;
  final path = Platform.isAndroid
      ? [...targetFolder, 'libaria2c.so']
      : Platform.isWindows
      ? [...targetFolder, 'aria2c.exe']
      : [...targetFolder, 'aria2c'];
  final file = File(pathJoin(path));
  if (!(await file.exists())) {
    logger('Not found aria2c at $path');
  }
  return path;
}

String pathJoin(List<String> path) =>
    (!Platform.isWindows ? '/' : '') + path.join('/');
