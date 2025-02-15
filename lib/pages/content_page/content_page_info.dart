import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:fnps/widgets/custom_badge.dart';
import 'package:provider/provider.dart';
import 'package:fnps/hooks/use_change_info.dart';
import 'package:fnps/hooks/use_content_info.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/utils/copy_to_clipboard.dart';
import 'package:fnps/utils/file_size_convert.dart';
import 'package:fnps/utils/get_localizations.dart';
import 'package:fnps/utils/uri.dart';

class ContentPageInfo extends HookWidget {
  const ContentPageInfo({
    super.key,
    required this.content,
    required this.contents,
    required this.downloadContents,
  });

  final Content content;
  final List<Content> contents;
  final void Function() downloadContents;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    final config = configProvider.config;
    String? hmacKey = config.hmacKey;

    final contentInfo = useContentInfo(content);
    final changeInfo = useChangeInfo(content, hmacKey);

    final update = useMemoized(
        () => contents
            .firstWhereOrNull((content) => content.category == Category.update),
        [contents]);

    final size = useMemoized(
        () => contents
            .map((item) => item.fileSize ?? 0)
            .reduce((value, element) => value + element),
        [contents]);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    // 图标
                    SizedBox(
                      width: 128,
                      height: 128,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: contentInfo.icon == null
                            ? const Center(child: Icon(Icons.gamepad))
                            : InkWell(
                                onTap: () => launchURL(contentInfo.icon!),
                                child: CachedNetworkImage(
                                  imageUrl: contentInfo.icon!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.gamepad),
                                ),
                              ),
                      ),
                    ),
                    // 信息
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          content.name,
                          style: const TextStyle(
                            fontSize: 24.0,
                          ),
                        ),
                        if (content.originalName != null)
                          Text('${content.originalName}'),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (content.region != null)
                              CustomBadge(
                                  text: content.region!.name, primary: true),
                            const SizedBox(width: 4),
                            CustomBadge(text: content.platform.name),
                            const SizedBox(width: 4),
                            CustomBadge(text: content.category.name),
                            const SizedBox(width: 4),
                            CustomBadge(text: content.titleID),
                            const SizedBox(width: 4),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (content.appVersion != null ||
                            update?.appVersion != null)
                          Text(
                              '${t.version}: ${update?.appVersion ?? content.appVersion}'),
                        if (content.fileSize != 0)
                          Text('${t.size}: ${fileSizeConv(size)}'),
                        if (content.contentID != null)
                          Text('${t.content_id}: ${content.contentID}'),
                        if (content.lastModificationDate != null)
                          Text(
                              '${t.last_modification_date}: ${content.lastModificationDate}')
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 各种按钮
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton(
                      onPressed: content.pkgDirectLink == null
                          ? null
                          : () => copyToClipboard(
                                context,
                                '${content.pkgDirectLink}',
                                t.download_link_copied,
                              ),
                      child: Text(content.pkgDirectLink == null
                          ? t.download_link_not_available
                          : t.copy_download_link),
                    ),
                    if (content.platform == Platform.psv)
                      ElevatedButton(
                        onPressed: content.zRIF == null
                            ? null
                            : () => copyToClipboard(
                                  context,
                                  '${content.zRIF}',
                                  t.zrif_copied,
                                ),
                        child: Text(content.zRIF == null
                            ? t.zrif_not_available
                            : '${t.copy} zRIF'),
                      ),
                  ],
                ),
                // 媒体
                contentInfo.media.isEmpty
                    ? const SizedBox()
                    : const SizedBox(height: 16),
                contentInfo.media.isEmpty
                    ? const SizedBox()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: contentInfo.media
                              .where((media) => media.contains('.png'))
                              .map(
                                (media) => Container(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap: () => launchURL(media),
                                      child: CachedNetworkImage(
                                        imageUrl: media,
                                        fit: BoxFit.contain,
                                        width: 480 / 3 * 2,
                                        height: 272 / 3 * 2,
                                        placeholder: (context, url) =>
                                            const SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ],
            ),
          ),
          // 描述
          if (contentInfo.desc != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: html.Html(
                data: contentInfo.desc,
              ),
            ),
          ...changeInfo.map((change) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      change.version,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: html.Html(
                      data: change.desc,
                    ),
                  ),
                ],
              ))
        ],
      ),
    );
  }
}
