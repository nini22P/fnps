import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/content_info.dart';
import 'package:vita_dl/utils/logger.dart';

class ContentInfo {
  final String? icon;
  final List<String> media;
  final String? desc;

  ContentInfo({
    required this.icon,
    required this.media,
    required this.desc,
  });
}

ContentInfo useContentInfo(Content content) {
  final contentID = useMemoized(() => content.contentID);
  if (contentID == null) return ContentInfo(icon: null, media: [], desc: null);

  final icon = useMemoized(() => getContentIcon(content));

  if (content.category == Category.update) {
    return ContentInfo(icon: icon, media: [], desc: null);
  }

  final apiUrl = useMemoized(() =>
      "$baseApiUrl/${regionMap[contentID.substring(0, 2)]}/999/$contentID");

  final media = useState<List<String>>([]);

  final desc = useState<String?>(null);

  useEffect(() {
    () async {
      try {
        logger(apiUrl);
        final data = await DefaultCacheManager().getSingleFile(apiUrl);
        final jsonString = await data.readAsString();
        final json = jsonDecode(jsonString);

        if (json['promomedia'] != null &&
            json['promomedia'] is List &&
            json['promomedia'].length > 0) {
          final promo = json['promomedia'][0];
          if (promo != null &&
              promo['materials'] != null &&
              promo['materials'] is List &&
              promo['materials'].length > 0) {
            for (var material in promo['materials']) {
              if (material['urls'] != null &&
                  material['urls'] is List &&
                  material['urls'].length > 0) {
                for (var urlObj in material['urls']) {
                  if (urlObj['url'] != null) {
                    media.value = [...media.value, urlObj['url']];
                  }
                }
              }
            }
          }
        }

        desc.value = json['long_desc']?.toString();
      } catch (e) {
        logger('Failed to fetch content info', error: e);
      }
    }();
    return null;
  }, []);

  return ContentInfo(icon: icon, media: media.value, desc: desc.value);
}
