import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';

Future<bool> downloadRAP(Content content) async {
  final contentID = content.contentID;
  final rap = content.rap;
  if (contentID == null || rap == null) {
    return false;
  }

  final List<String> downloadsPath = await getDownloadsPath();
  final List<String> directory = [...downloadsPath, content.titleID];

  final rapUrl = getRAPUrl(contentID, rap);
  final path = pathJoin([...directory, '$contentID.rap']);
  logger('Downloading rap: $rapUrl');
  Response response = await Dio().download(rapUrl, path);
  if (response.statusCode == HttpStatus.ok) {
    logger('RAP file saved to: $path');
    return true;
  }
  return false;
}

String getRAPUrl(String contentID, String rap) =>
    'https://nopaystation.com/tools/rap2file/$contentID/$rap';
