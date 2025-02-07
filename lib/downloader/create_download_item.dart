import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/utils/path.dart';

Future<DownloadItem?> createDownloadItem(Content content) async {
  final url = content.pkgDirectLink;
  final id = content.contentID;
  if (url == null || id == null) {
    return null;
  }

  final List<String> downloadsPath = await getDownloadsPath();
  final String name = '${content.contentID}.pkg';
  final List<String> directory = [...downloadsPath, content.titleID];

  final item = DownloadItem(
    id: id,
    name: name,
    directory: directory,
    size: content.fileSize ?? 0,
    content: content,
  );

  return item;
}
