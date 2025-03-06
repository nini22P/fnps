import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/pages/show_source_dialog.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/widgets/custom_badge.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/config.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/utils/get_localizations.dart';
import 'package:fnps/utils/platform.dart';
import 'package:fnps/utils/tsv_to_contents.dart';
import 'package:fnps/utils/uri.dart';

enum SyncStatus {
  queue,
  syncing,
  done,
}

class SourceTile {
  final String title;
  final Platform platform;
  final Category category;
  final SyncStatus status;

  SourceTile({
    required this.title,
    required this.platform,
    required this.category,
    required this.status,
  });
}

class Settings extends HookWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final configProvider = Provider.of<ConfigProvider>(context);

    final getPackageInfo =
        useMemoized(() async => await PackageInfo.fromPlatform());

    final packageInfo = useFuture(getPackageInfo).data;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final psvBox = Hive.box<Content>(psvBoxName);
    final pspBox = Hive.box<Content>(pspBoxName);
    final psmBox = Hive.box<Content>(psmBoxName);
    final psxBox = Hive.box<Content>(psxBoxName);
    final ps3Box = Hive.box<Content>(ps3BoxName);
    final downloadBox = Hive.box<DownloadItem>(downloadBoxName);

    final TextEditingController hmacKeyController =
        TextEditingController(text: configProvider.config.hmacKey);

    final sourceTileData = useState([
      SourceTile(
        title: 'PSV ${t.game_list}',
        platform: Platform.psv,
        category: Category.game,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSV ${t.dlc_list}',
        platform: Platform.psv,
        category: Category.dlc,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSV ${t.theme_list}',
        platform: Platform.psv,
        category: Category.theme,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSV ${t.update_list}',
        platform: Platform.psv,
        category: Category.update,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSV ${t.demo_list}',
        platform: Platform.psv,
        category: Category.demo,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSP ${t.game_list}',
        platform: Platform.psp,
        category: Category.game,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSP ${t.dlc_list}',
        platform: Platform.psp,
        category: Category.dlc,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSP ${t.theme_list}',
        platform: Platform.psp,
        category: Category.theme,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSP ${t.update_list}',
        platform: Platform.psp,
        category: Category.update,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSM ${t.game_list}',
        platform: Platform.psm,
        category: Category.game,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PSX ${t.game_list}',
        platform: Platform.psx,
        category: Category.game,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PS3 ${t.game_list}',
        platform: Platform.ps3,
        category: Category.game,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PS3 ${t.dlc_list}',
        platform: Platform.ps3,
        category: Category.dlc,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PS3 ${t.theme_list}',
        platform: Platform.ps3,
        category: Category.theme,
        status: SyncStatus.done,
      ),
      SourceTile(
        title: 'PS3 ${t.demo_list}',
        platform: Platform.ps3,
        category: Category.demo,
        status: SyncStatus.done,
      ),
    ]);

    final isSync = useMemoized(
        () => sourceTileData.value.any((tile) =>
            tile.status == SyncStatus.syncing ||
            tile.status == SyncStatus.queue),
        [sourceTileData.value]);

    Future<void> updateContents({
      required List<Content> contents,
      required Platform platform,
      required Category category,
      String? url,
    }) async {
      switch (platform) {
        case Platform.psv:
          final values = [...psvBox.values]
              .where((content) => content.category != category);
          await psvBox.clear();
          await psvBox.addAll([...values, ...contents]);
          break;
        case Platform.psp:
          final values = [...pspBox.values]
              .where((content) => content.category != category);
          await pspBox.clear();
          await pspBox.addAll([...values, ...contents]);
          break;
        case Platform.psm:
          final values = [...psmBox.values]
              .where((content) => content.category != category);
          await psmBox.clear();
          await psmBox.addAll([...values, ...contents]);
          break;
        case Platform.psx:
          final values = [...psxBox.values]
              .where((content) => content.category != category);
          await psxBox.clear();
          await psxBox.addAll([...values, ...contents]);
          break;
        case Platform.ps3:
          final values = [...ps3Box.values]
              .where((content) => content.category != category);
          await ps3Box.clear();
          await ps3Box.addAll([...values, ...contents]);
          break;
        default:
          break;
      }

      final filteredSources = [...configProvider.config.sources]
          .whereNot((source) =>
              source.platform == platform && source.category == category)
          .toList();
      configProvider.updateConfig(configProvider.config.copyWith(
        sources: [
          ...filteredSources,
          Source(
            platform: platform,
            category: category,
            updateTime: DateTime.now().toUtc(),
            url: url,
          )
        ],
      ));
    }

    void updateSourceTileData(SourceTile tile) {
      final updatedTiles = sourceTileData.value
          .where((item) => !(item.platform == tile.platform &&
              item.category == tile.category))
          .toList();

      int insertIndex = sourceTileData.value.indexWhere((item) =>
          item.platform == tile.platform && item.category == tile.category);

      if (insertIndex == -1) {
        updatedTiles.add(tile);
      } else {
        updatedTiles.insert(insertIndex, tile);
      }

      sourceTileData.value = updatedTiles;
    }

    Source? getSource(Platform platform, Category category) =>
        configProvider.config.sources.firstWhereOrNull((source) =>
            source.platform == platform && source.category == category);

    Future<void> syncSource(SourceTile tile, String url) async {
      String? content;
      logger('Downloading ${tile.platform.name} ${tile.category.name}...');
      updateSourceTileData(SourceTile(
        title: tile.title,
        platform: tile.platform,
        category: tile.category,
        status: SyncStatus.syncing,
      ));
      try {
        Dio dio = Dio();

        Response response = await dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );

        if (response.statusCode == 200) {
          content = utf8.decode(response.data);
        } else {
          updateSourceTileData(SourceTile(
            title: tile.title,
            platform: tile.platform,
            category: tile.category,
            status: SyncStatus.done,
          ));
          logger('Download failed: ${response.statusCode}',
              error: response.statusMessage);
        }
      } catch (e) {
        updateSourceTileData(SourceTile(
          title: tile.title,
          platform: tile.platform,
          category: tile.category,
          status: SyncStatus.done,
        ));
        logger('Download failed:', error: e);
      }

      if (content != null) {
        logger('Parsing ${tile.platform.name} ${tile.category.name}...');
        final contents =
            await tsvToContents(content, tile.platform, tile.category);
        await updateContents(
          contents: contents,
          platform: tile.platform,
          category: tile.category,
          url: url,
        );

        updateSourceTileData(SourceTile(
          title: tile.title,
          platform: tile.platform,
          category: tile.category,
          status: SyncStatus.done,
        ));
        logger('Synced ${tile.platform.name} ${tile.category.name}');
      }
    }

    Future<void> syncAllSources() async {
      logger('Syncing all sources...');
      sourceTileData.value = sourceTileData.value.map((tile) {
        final source = getSource(tile.platform, tile.category);
        if (source != null && source.url != null) {
          return SourceTile(
            title: tile.title,
            platform: tile.platform,
            category: tile.category,
            status: SyncStatus.queue,
          );
        } else {
          return tile;
        }
      }).toList();
      for (var tile in sourceTileData.value) {
        final source = getSource(tile.platform, tile.category);
        if (source != null && source.url != null) {
          await syncSource(tile, source.url!);
        }
      }
    }

    Future<void> selectLocalFile(Platform platform, Category category) async {
      String? content;

      if (isAndroid) {
        SafDocumentFile? file = await SafUtil().pickFile(mimeTypes: [
          'text/tab-separated-values',
          'text/comma-separated-values',
        ]);
        if (file != null) {
          List<int> fileBytes = await SafStream().readFileBytes(file.uri);
          content = utf8.decode(fileBytes);
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['tsv', 'csv'],
          withData: true,
        );
        final filePath = result?.files.single.path;
        if (filePath != null) {
          content = await File(filePath).readAsString();
        }
      }

      if (content != null) {
        final contents = await tsvToContents(content, platform, category);
        await updateContents(
          contents: contents,
          platform: platform,
          category: category,
        );
      }
    }

    ListTile buildSourceTile(SourceTile tile) {
      final source = getSource(tile.platform, tile.category);
      final url = source?.url;

      final contents = [
        ...psvBox.values,
        ...pspBox.values,
        ...psmBox.values,
        ...psxBox.values,
        ...ps3Box.values,
      ];

      final contentsLength = contents
          .where((content) =>
              content.platform == tile.platform &&
              content.category == tile.category)
          .length;

      return ListTile(
        title: Text(tile.title),
        subtitle: Row(
          spacing: 4,
          children: [
            CustomBadge(text: url == null ? t.local : t.remote),
            if (contentsLength > 0)
              CustomBadge(text: contentsLength.toString()),
            if (tile.status == SyncStatus.done && contentsLength == 0)
              CustomBadge(text: url == null ? t.not_added : t.not_syncing),
            if (tile.status == SyncStatus.syncing) CustomBadge(text: t.syncing),
            if (tile.status == SyncStatus.queue) CustomBadge(text: t.queuing),
            Expanded(
              child: Text(
                !isMobile && url != null ? url : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (source?.updateTime != null && contentsLength > 0)
              Text(source!.updateTime!
                  .toLocal()
                  .toIso8601String()
                  .replaceAll('T', ' ')
                  .split('.')
                  .first),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (url != null)
            IconButton(
              tooltip: t.sync,
              icon: const Icon(Icons.sync),
              onPressed: tile.status != SyncStatus.done
                  ? null
                  : () => syncSource(tile, url),
            ),
        ]),
        onTap: tile.status != SyncStatus.done || source == null
            ? null
            : () async {
                final result =
                    await showSourceDialog(context, source, tile.title);
                if (result == null) return;
                if (result.url == null) {
                  await selectLocalFile(tile.platform, tile.category);
                } else {
                  await syncSource(tile, result.url!);
                }
              },
      );
    }

    tilesBuilder() {
      List<Widget> result = [];
      for (var tile in sourceTileData.value) {
        if ((tile.platform == Platform.psp ||
                tile.platform == Platform.psm ||
                tile.platform == Platform.ps3) &&
            tile.category == Category.game) {
          result.add(const Divider());
        }
        result.add(buildSourceTile(tile));
      }
      return result;
    }

    final List<Widget> tiles = tilesBuilder();

    Future<void> updateHmacKey(String hmacKey) async => configProvider
        .updateConfig(configProvider.config.copyWith(hmacKey: hmacKey));

    Future<void> resetConfig() async {
      await psvBox.clear();
      await pspBox.clear();
      await psmBox.clear();
      await psxBox.clear();
      await ps3Box.clear();
      await downloadBox.clear();
      await configProvider.resetConfig();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
        forceMaterialTransparency: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: Text(t.sync_all_remote_lists),
              onTap: isSync ? null : syncAllSources,
            ),
            const Divider(),
            ...tiles,
            const Divider(),
            ListTile(
              title: Text(t.hmac_key),
              subtitle: configProvider.config.hmacKey == null
                  ? null
                  : Text(configProvider.config.hmacKey!),
              onTap: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(t.hmac_key),
                  content: TextField(
                    controller: hmacKeyController,
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'Cancal'),
                      child: Text(t.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        updateHmacKey(hmacKeyController.text);
                        Navigator.pop(context, 'OK');
                      },
                      child: Text(t.ok),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            ListTile(
              title: Text(t.reset_config),
              subtitle: Text(t.reset_config_subtitle),
              onTap: resetConfig,
            ),
            const Divider(),
            ListTile(
              title: const Text('FNPS'),
              subtitle: const Text('Flutter NoPayStation client'),
              onTap: () => launchURL('https://github.com/nini22P/fnps'),
            ),
            ListTile(
              title: Text(t.version),
              subtitle: Text('${packageInfo?.version}'),
            ),
          ],
        ),
      ),
    );
  }
}
