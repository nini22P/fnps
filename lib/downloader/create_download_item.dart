import 'package:fnps/models/content.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/utils/path.dart';

Future<DownloadItem?> createDownloadItem(Content content) async {
  final url = content.pkgDirectLink;
  final id = content.getID();
  if (url == null || id == null) {
    return null;
  }

  final List<String> downloadsPath = await getDownloadsPath();
  final String filename = '$id.pkg';
  final List<String> directory = [...downloadsPath, content.titleID];

  final item = DownloadItem(
    id: id,
    filename: filename,
    directory: directory,
    size: content.fileSize ?? 0,
    content: content,
  );

  return item;
}
