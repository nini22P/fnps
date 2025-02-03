import 'dart:convert';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:vita_dl/models/content.dart';
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

class ContentInfo {
  final List<String> images;
  final String desc;

  ContentInfo({
    required this.images,
    required this.desc,
  });
}

String? getContentIconUrl(Content content) => content.contentID == null
    ? null
    : "$baseApiUrl/${regionMap[content.contentID?.substring(0, 2)]}/999/${content.contentID}/image";

Future<ContentInfo> getContentInfo(String contentID) async {
  final infoUrl =
      "$baseApiUrl/${regionMap[contentID.substring(0, 2)]}/999/$contentID";

  try {
    final data = await DefaultCacheManager().getSingleFile(infoUrl);
    final jsonString = await data.readAsString();
    final json = jsonDecode(jsonString);

    List<String> images = [];

    for (var promo in json['promomedia']) {
      for (var material in promo['materials']) {
        for (var urlObj in material['urls']) {
          images.add(urlObj['url']);
        }
      }
    }

    final desc = json['long_desc'] ?? '';

    return ContentInfo(images: images, desc: desc);
  } catch (e) {
    return ContentInfo(images: [], desc: '');
  }
}

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

Future<Content?> getUpdateLink(String titleID, String hmacKey) async {
  var xmlLink = getUpdateXmlLink(titleID, hmacKey);

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

      final version = package.getAttribute('version') ?? '';
      final size = package.getAttribute('size') ?? '';
      final url = package.getAttribute('url') ?? '';

      return Content(
        type: ContentType.update,
        titleID: titleID,
        name: titleID,
        appVersion: version,
        fileSize: int.tryParse(size),
        pkgDirectLink: url,
      );
    }
  } catch (e) {
    return null;
  }
  return null;
}
