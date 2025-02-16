import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';

Future<bool> downloadRAP(Content content) async {
  if (content.rap == null ||
      content.rap!.isEmpty ||
      content.contentID == null) {
    return false;
  }

  final List<String> downloadsPath = await getDownloadsPath();
  final List<String> directory = [...downloadsPath, content.titleID];

  final rapUrl =
      'https://nopaystation.com/tools/rap2file/${content.contentID}/${content.rap}';
  final path = pathJoin([...directory, '${content.contentID}.rap']);
  logger('Downloading rap: $rapUrl');
  Response response = await Dio().download(rapUrl, path);
  if (response.statusCode == HttpStatus.ok) {
    logger('RAP file saved to: $path');
    return true;
  }
  return false;
}
