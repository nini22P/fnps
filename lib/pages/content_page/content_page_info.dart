import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vita_dl/downloader/downloader.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/utils/content_info.dart';
import 'package:vita_dl/utils/file_size_convert.dart';
import 'package:vita_dl/utils/get_localizations.dart';
import 'package:vita_dl/utils/uri.dart';

class ContentPageInfo extends HookWidget {
  const ContentPageInfo({super.key, required this.content});

  final Content content;

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    final config = configProvider.config;
    String? hmacKey = config.hmacKey;

    final dlcBox = useMemoized(() => Hive.box<Content>(dlcBoxName));
    final themeBox = useMemoized(() => Hive.box<Content>(themeBoxName));
    final downloadBox =
        useMemoized(() => Hive.box<DownloadItem>(downloadBoxName));

    final downloader = Downloader.instance;

    List<Content> getDLCs() => content.type != ContentType.app
        ? []
        : dlcBox.values
            .where((item) => content.titleID == item.titleID)
            .toList();

    List<Content> getThemes() => content.type != ContentType.app
        ? []
        : themeBox.values
            .where((item) => content.titleID == item.titleID)
            .toList();

    Future<Content?> getUpdate(String hmacKey) async =>
        content.type != ContentType.app || hmacKey.isEmpty
            ? null
            : await getUpdateLink(content, hmacKey);

    final updateFuture =
        useMemoized(() => hmacKey == null ? null : getUpdate(hmacKey));
    final contentInfoFuture = useMemoized(() =>
        content.contentID == null ? null : getContentInfo(content.contentID!));

    final String? iconUrl = getContentIconUrl(content);
    final contentInfo = useFuture(contentInfoFuture).data;
    final update = useFuture(updateFuture).data;
    final dlcs = useMemoized(() => getDLCs());
    final themes = useMemoized(() => getThemes());

    final downloads = useListenable(downloadBox.listenable()).value;

    final int size = useMemoized(() {
      int size = 0;
      size = size + (content.fileSize ?? 0) + (update?.fileSize ?? 0);
      for (var dlc in dlcs) {
        size = size + (dlc.fileSize ?? 0);
      }
      for (var theme in themes) {
        size = size + (theme.fileSize ?? 0);
      }
      return size;
    }, [content, update, dlcs, themes]);

    Future<void> copyToClipboard(String text, String description) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(description)),
        );
      }
    }

    void downloadContents() {
      final contents = [
        content,
        if (update != null) update,
        if (dlcs.isNotEmpty) ...dlcs,
        if (themes.isNotEmpty) ...themes,
      ];
      downloader.add(contents);
    }

    return SingleChildScrollView(
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
                    iconUrl == null
                        ? const Icon(Icons.gamepad)
                        : SizedBox(
                            width: 128,
                            height: 128,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => launchURL(iconUrl),
                                child: CachedNetworkImage(
                                  imageUrl: iconUrl,
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
                              Badge(
                                label: Text(content.region!),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                              ),
                            const SizedBox(width: 4),
                            Badge(
                              label: Text(content.type.name.toUpperCase()),
                              backgroundColor: Colors.blueGrey,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            ),
                            const SizedBox(width: 4),
                            Badge(
                              label: Text(content.titleID),
                              backgroundColor: Colors.blueGrey,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                            ),
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 各种按钮
                if (content.type == ContentType.app)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ElevatedButton(
                        onPressed: content.pkgDirectLink == null
                            ? null
                            : () => downloadContents(),
                        child: Text(
                          content.pkgDirectLink == null
                              ? t.download_link_not_available
                              : t.download_all_items,
                        ),
                      ),
                    ],
                  ),
                if (content.type != ContentType.app)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ElevatedButton(
                        onPressed: content.pkgDirectLink == null
                            ? null
                            : () => downloader.add([content]),
                        child: Text(content.pkgDirectLink == null
                            ? t.download_link_not_available
                            : t.download),
                      ),
                      content.pkgDirectLink == null
                          ? const SizedBox()
                          : ElevatedButton(
                              onPressed: () => copyToClipboard(
                                  '${content.pkgDirectLink}',
                                  t.download_link_copied),
                              child: Text(content.pkgDirectLink == null
                                  ? t.download_link_not_available
                                  : t.copy_download_link),
                            ),
                      ElevatedButton(
                        onPressed: content.zRIF == null
                            ? null
                            : () => copyToClipboard(
                                '${content.zRIF}', t.zrif_copied),
                        child: Text(content.zRIF == null
                            ? t.zrif_not_available
                            : '${t.copy} zRIF'),
                      ),
                    ],
                  ),
                // 截图
                contentInfo == null || contentInfo.images.isEmpty
                    ? const SizedBox()
                    : const SizedBox(height: 16),
                contentInfo == null || contentInfo.images.isEmpty
                    ? const SizedBox()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: contentInfo.images
                              .map(
                                (image) => Container(
                                  padding: const EdgeInsets.all(4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap: () => launchURL(image),
                                      child: CachedNetworkImage(
                                        imageUrl: image,
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
          contentInfo == null || contentInfo.desc.isEmpty
              ? const SizedBox()
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: html.Html(
                    data: contentInfo.desc,
                  ),
                ),
        ],
      ),
    );
  }
}
