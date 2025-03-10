import 'dart:io';
import 'package:android_x_storage/android_x_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fnps/utils/get_native_library_dir.dart';
import 'package:fnps/utils/platform.dart';
import 'package:fnps/utils/path_conv.dart';
import 'package:fnps/utils/pkg.dart';
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
  final appPath = await getAppPath();
  final targetFolder = Platform.isAndroid ? nativeLibraryPath : appPath;
  final path = Platform.isAndroid
      ? [...targetFolder, 'libpkg2zip.so']
      : Platform.isWindows
          ? [...targetFolder, 'pkg2zip.exe']
          : [...targetFolder, 'pkg2zip'];
  final file = File(pathJoin(path));
  if (!await file.exists()) {
    await copyPkg2zip(path);
  }
  return path;
}

String pathJoin(List<String> path) =>
    (!Platform.isWindows ? '/' : '') + path.join('/');
