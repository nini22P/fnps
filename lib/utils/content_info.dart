import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/utils/logger.dart';
import 'package:xml/xml.dart';
import 'package:crypto/crypto.dart';

const String baseApiUrl =
    "https://store.playstation.com/store/api/chihiro/00_09_000/container";

Map<String, String> regionMap = {
  "EP": "sa/en",
  "UP": "us/en",
  "JP": "jp/ja",
  "KP": "kr/ko",
  "HP": "hk/zh",
};

String? getContentIcon(Content content, {int? size}) => content.contentID ==
        null
    ? null
    : "$baseApiUrl/${regionMap[content.contentID?.substring(0, 2)]}/999/${content.contentID}/image${size == null ? '' : '?w=$size&h=$size'}";

String getUpdateXmlLink(String titleID, String hmacKey) {
  List<int> binary = [];
  String key = "0x$hmacKey";

  for (int i = 2; i < key.length; i += 2) {
    String s = key.substring(i, i + 2);
    binary.add(int.parse(s, radix: 16));
  }

  var hmac = Hmac(sha256, binary);
  var byteHash = hmac.convert(utf8.encode("np_$titleID")).bytes;

  String hash = byteHash
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toLowerCase();

  return "http://gs-sec.ww.np.dl.playstation.net/pl/np/$titleID/$hash/$titleID-ver.xml";
}

class UpdateInfo {
  final String version;
  final int size;
  final String url;
  final String sha1sum;
  final String? changeInfoUrl;

  UpdateInfo({
    required this.version,
    required this.size,
    required this.url,
    required this.sha1sum,
    this.changeInfoUrl,
  });
}

Future<UpdateInfo?> getUpdateInfo(Content content, String hmacKey) async {
  final titleID = content.titleID;
  var xmlLink = getUpdateXmlLink(titleID, hmacKey);

  logger(xmlLink);

  try {
    final data = await DefaultCacheManager().getSingleFile(xmlLink);
    final contents = await data.readAsString();
    final document = XmlDocument.parse(contents);

    if (document.findElements('Error').isNotEmpty) {
      return null;
    }

    if (document.findElements('titlepatch').isNotEmpty) {
      final titlePatch = document.findAllElements('titlepatch').first;
      final tag = titlePatch.findElements('tag').first;

      final package = tag.findElements('package').first;

      final version = package.getAttribute('version');
      final size = int.tryParse(package.getAttribute('size') ?? '0');
      final url = package.getAttribute('url');
      final sha1sum = package.getAttribute('sha1sum');

      final changeinfo = package.findElements('changeinfo').first;
      final changeInfoUrl = changeinfo.getAttribute('url');

      if (version == null || size == null || url == null || sha1sum == null) {
        return null;
      }

      return UpdateInfo(
        version: version,
        size: size,
        url: url,
        sha1sum: sha1sum,
        changeInfoUrl: changeInfoUrl,
      );
    }
  } catch (e) {
    return null;
  }
  return null;
}

Future<Content?> getUpdate(Content content, String hmacKey) async {
  final titleID = content.titleID;
  final updateinfo = await getUpdateInfo(content, hmacKey);

  if (updateinfo != null) {
    return Content(
      platform: content.platform,
      category: Category.update,
      titleID: titleID,
      name: '${content.name} ${updateinfo.version}',
      appVersion: updateinfo.version,
      fileSize: updateinfo.size,
      pkgDirectLink: updateinfo.url,
      contentID: content.contentID,
      originalName: content.originalName,
      sha1sum: updateinfo.sha1sum,
      zRIF: content.zRIF,
    );
  }

  return null;
}

class Change {
  final String version;
  final String desc;

  Change({required this.version, required this.desc});
}

Future<List<Change>> getChangeInfo(String url) async {
  final changeInfo = <Change>[];
  try {
    final data = await DefaultCacheManager().getSingleFile(url);
    final contents = await data.readAsString();
    final document = XmlDocument.parse(contents);

    final changeinfo = document.findAllElements('changes');

    for (final changes in changeinfo) {
      final version = changes.getAttribute('app_ver');
      final desc = changes.innerText;

      if (version != null) {
        changeInfo.add(Change(version: version, desc: desc));
      }
    }
  } catch (e) {
    logger('getChangeInfo error', error: e);
  }
  return changeInfo;
}
