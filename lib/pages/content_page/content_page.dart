import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vita_dl/downloader/downloader.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/pages/content_list.dart';
import 'package:vita_dl/pages/content_page/content_page_info.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/utils/content_info.dart';
import 'package:vita_dl/utils/get_localizations.dart';

class ITab {
  final String title;
  final Widget child;

  const ITab({
    required this.title,
    required this.child,
  });
}

class ContentPageProps {
  final Content content;
  final int? initialIndex;

  const ContentPageProps({
    required this.content,
    this.initialIndex,
  });
}

class ContentPage extends HookWidget {
  const ContentPage({
    super.key,
    required this.props,
  });

  final ContentPageProps props;

  Content get content => props.content;
  int? get initialIndex => props.initialIndex;

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
    final update = useFuture(updateFuture).data;
    final dlcs = useMemoized(() => getDLCs());
    final themes = useMemoized(() => getThemes());

    final downloads = useListenable(downloadBox.listenable()).value;

    List<Content> contents = useMemoized(
        () => [
              content,
              if (update != null) update,
              ...dlcs,
              ...themes,
            ],
        [update, dlcs, themes]);

    final canDownloadContents = useMemoized(
        () => contents.where((item) => item.pkgDirectLink != null).toList(),
        [contents]);

    final currentDownloads = useMemoized(
        () => downloads.values
            .where((item) => contents.contains(item.content))
            .toList(),
        [downloads.values, contents]);

    final currentCompletedDownloads = useMemoized(
        () => currentDownloads
            .where((item) => item.extractStatus == ExtractStatus.completed),
        [currentDownloads]);

    bool isDownloading = useMemoized(
        () => currentDownloads
            .any((item) => item.downloadStatus == DownloadStatus.downloading),
        [currentDownloads]);

    final incompletedDownloads = useMemoized(
        () => currentDownloads
            .where((item) => item.extractStatus != ExtractStatus.completed)
            .toList(),
        [currentDownloads]);

    final tabController = useTabController(
      initialLength: 2,
      initialIndex: initialIndex ?? 0,
    );

    void downloadContents() {
      downloader.add(canDownloadContents);
      tabController.animateTo(1);
    }

    List<ITab> tabs = [
      ITab(
        title: t.info,
        child: ContentPageInfo(
          content: content,
          downloadContents: downloadContents,
        ),
      ),
      ITab(
        title: t.contents,
        child: ContentList(contents: contents),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${content.name} [${content.titleID}]'),
        bottom: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: tabs.map((e) => Tab(text: e.title)).toList()),
      ),
      body: TabBarView(
        controller: tabController,
        children: tabs.map((e) => e.child).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(isDownloading ? Icons.pause : Icons.download),
        label: Text(currentDownloads.isEmpty
            ? t.download_all_downloadable_content
            : currentDownloads.length == canDownloadContents.length
                ? '${t.downloaded} ${currentCompletedDownloads.length} / ${currentDownloads.length}'
                : '${t.downloaded} ${currentCompletedDownloads.length} / ${currentDownloads.length} / ${canDownloadContents.length}'),
        onPressed: () => isDownloading
            ? downloader.pause(contents)
            : incompletedDownloads.isNotEmpty
                ? downloader
                    .add(incompletedDownloads.map((e) => e.content).toList())
                : downloadContents(),
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }
}
