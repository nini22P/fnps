import 'package:fnps/utils/path.dart';
import 'package:fnps/utils/platform.dart';
import 'package:open_dir/open_dir.dart';
import 'package:open_file_manager/open_file_manager.dart';

Future<bool> openExplorer({
  required List<String> dir,
  String? highlightedFileName,
}) async {
  if (isDesktop) {
    final openDirPlugin = OpenDir();
    return await openDirPlugin.openNativeDir(
          path: pathJoin(dir),
          highlightedFileName: highlightedFileName,
        ) ??
        false;
  } else if (isAndroid || isIOS) {
    return await openFileManager(
      androidConfig: AndroidConfig(
        folderType: FolderType.other,
        folderPath: pathJoin(dir),
      ),
    );
  }

  return false;
}
