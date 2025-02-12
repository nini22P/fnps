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
import 'package:vita_dl/utils/get_contents_by_title_id.dart';
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

    final downloadBox =
        useMemoized(() => Hive.box<DownloadItem>(downloadBoxName));

    final downloader = Downloader.instance;

    final downloads = useListenable(downloadBox.listenable()).value;

    final getContents = useMemoized(() async => content.type != ContentType.app
        ? [content]
        : await getContentsByTitleID(content.titleID, hmacKey));

    List<Content> contents = useFuture(getContents).data ?? [];

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
      floatingActionButton: canDownloadContents.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: Icon(isDownloading ? Icons.pause : Icons.download),
              label: Text(currentDownloads.isEmpty
                  ? canDownloadContents.length == 1 &&
                          content.pkgDirectLink != null
                      ? t.download
                      : t.download_all_downloadable_content
                  : currentDownloads.length == canDownloadContents.length
                      ? '${t.downloaded} ${currentCompletedDownloads.length} / ${currentDownloads.length}'
                      : '${t.downloaded} ${currentCompletedDownloads.length} / ${currentDownloads.length} / ${canDownloadContents.length}'),
              onPressed: () => isDownloading
                  ? downloader.pause(contents)
                  : incompletedDownloads.isNotEmpty
                      ? downloader.add(
                          incompletedDownloads.map((e) => e.content).toList())
                      : downloadContents(),
            ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
    );
  }
}
