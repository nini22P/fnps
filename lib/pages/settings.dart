import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/pages/show_pkg2zip_output_mode_dialog.dart';
import 'package:fnps/pages/show_source_dialog.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/source_sorter.dart';
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

class Settings extends HookWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final configProvider = Provider.of<ConfigProvider>(context);

    final getPackageInfo = useMemoized(
      () async => await PackageInfo.fromPlatform(),
    );

    final packageInfo = useFuture(getPackageInfo).data;

    final TextEditingController hmacKeyController = TextEditingController(
      text: configProvider.config.hmacKey,
    );

    final isSync = useMemoized(
      () => configProvider.config.sources.any(
        (source) =>
            source.syncStatus == SyncStatus.syncing ||
            source.syncStatus == SyncStatus.queue,
      ),
      [configProvider.config.sources],
    );

    Future<void> updateContents({
      required List<Content> contents,
      required Platform platform,
      required Category category,
      String? url,
    }) async {
      final psvBox = Hive.box<Content>(psvBoxName);
      final pspBox = Hive.box<Content>(pspBoxName);
      final psmBox = Hive.box<Content>(psmBoxName);
      final psxBox = Hive.box<Content>(psxBoxName);
      final ps3Box = Hive.box<Content>(ps3BoxName);

      switch (platform) {
        case Platform.psv:
          final values = [
            ...psvBox.values,
          ].where((content) => content.category != category);
          await psvBox.clear();
          await psvBox.addAll([...values, ...contents]);
          break;
        case Platform.psp:
          final values = [
            ...pspBox.values,
          ].where((content) => content.category != category);
          await pspBox.clear();
          await pspBox.addAll([...values, ...contents]);
          break;
        case Platform.psm:
          final values = [
            ...psmBox.values,
          ].where((content) => content.category != category);
          await psmBox.clear();
          await psmBox.addAll([...values, ...contents]);
          break;
        case Platform.psx:
          final values = [
            ...psxBox.values,
          ].where((content) => content.category != category);
          await psxBox.clear();
          await psxBox.addAll([...values, ...contents]);
          break;
        case Platform.ps3:
          final values = [
            ...ps3Box.values,
          ].where((content) => content.category != category);
          await ps3Box.clear();
          await ps3Box.addAll([...values, ...contents]);
          break;
        default:
          break;
      }

      final filteredSources = [...configProvider.config.sources]
          .whereNot(
            (source) =>
                source.platform == platform && source.category == category,
          )
          .toList();
      configProvider.updateConfig(
        configProvider.config.copyWith(
          sources: sourceSorter([
            ...filteredSources,
            Source(
              platform: platform,
              category: category,
              updateTime: DateTime.now().toUtc(),
              url: url,
              count: contents.length,
              syncStatus: SyncStatus.done,
            ),
          ]),
        ),
      );
    }

    void updateSourceStatus(
      Platform platform,
      Category category,
      SyncStatus status,
    ) {
      final updatedSources = configProvider.config.sources.map((source) {
        if (source.platform == platform && source.category == category) {
          return source.copyWith(syncStatus: status);
        }
        return source;
      }).toList();

      configProvider.updateConfig(
        configProvider.config.copyWith(sources: updatedSources),
      );
    }

    Future<void> syncSource(Source source, String url) async {
      String? content;
      logger('Downloading ${source.platform.name} ${source.category.name}...');
      updateSourceStatus(source.platform, source.category, SyncStatus.syncing);

      try {
        Dio dio = Dio();

        Response response = await dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );

        if (response.statusCode == 200) {
          content = utf8.decode(response.data);
        } else {
          updateSourceStatus(
            source.platform,
            source.category,
            source.count > 0 ? SyncStatus.done : SyncStatus.notSyncing,
          );
          logger(
            'Download failed: ${response.statusCode}',
            error: response.statusMessage,
          );
        }
      } catch (e) {
        updateSourceStatus(
          source.platform,
          source.category,
          source.count > 0 ? SyncStatus.done : SyncStatus.notSyncing,
        );
        logger('Download failed:', error: e);
      }

      if (content != null) {
        logger('Parsing ${source.platform.name} ${source.category.name}...');
        final contents = await tsvToContents(
          content,
          source.platform,
          source.category,
        );
        await updateContents(
          contents: contents,
          platform: source.platform,
          category: source.category,
          url: url,
        );
        logger('Synced ${source.platform.name} ${source.category.name}');
      }
    }

    Future<void> syncAllSources() async {
      logger('Syncing all sources...');

      final updatedSources = configProvider.config.sources.map((source) {
        if (source.url != null) {
          return source.copyWith(syncStatus: SyncStatus.queue);
        }
        return source;
      }).toList();

      configProvider.updateConfig(
        configProvider.config.copyWith(sources: updatedSources),
      );

      for (var source in configProvider.config.sources) {
        if (source.url != null) {
          await syncSource(source, source.url!);
        }
      }
    }

    Future<void> selectLocalFile(Platform platform, Category category) async {
      String? content;

      if (isAndroid) {
        SafDocumentFile? file = await SafUtil().pickFile(
          mimeTypes: [
            'text/tab-separated-values',
            'text/comma-separated-values',
          ],
        );
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

    String getSourceTitle(Source source) {
      final platformName = source.platform.name.toUpperCase();
      final categoryName = switch (source.category) {
        Category.game => t.game_list,
        Category.dlc => t.dlc_list,
        Category.theme => t.theme_list,
        Category.update => t.update_list,
        Category.demo => t.demo_list,
      };
      return '$platformName $categoryName';
    }

    ListTile buildSourceTile(Source source) {
      final url = source.url;
      final cont = source.count;
      final title = getSourceTitle(source);

      return ListTile(
        title: Text(title),
        subtitle: Row(
          spacing: 4,
          children: [
            CustomBadge(text: url == null ? t.local : t.remote),
            if (cont > 0) CustomBadge(text: cont.toString()),
            if (source.syncStatus == SyncStatus.notSyncing)
              CustomBadge(text: url == null ? t.not_added : t.not_syncing),
            if (source.syncStatus == SyncStatus.syncing)
              CustomBadge(text: t.syncing),
            if (source.syncStatus == SyncStatus.queue)
              CustomBadge(text: t.queuing),
            if (url != null)
              Expanded(
                child: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            if (source.updateTime != null && cont > 0)
              Text(
                source.updateTime!
                    .toLocal()
                    .toIso8601String()
                    .replaceAll('T', ' ')
                    .split('.')
                    .first,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (url != null)
              IconButton(
                tooltip: t.sync,
                icon: const Icon(Icons.sync_rounded),
                onPressed:
                    source.syncStatus == SyncStatus.syncing ||
                        source.syncStatus == SyncStatus.queue
                    ? null
                    : () => syncSource(source, url),
              ),
          ],
        ),
        onTap:
            source.syncStatus == SyncStatus.syncing ||
                source.syncStatus == SyncStatus.queue
            ? null
            : () async {
                final result = await showSourceDialog(context, source, title);
                if (result == null) return;
                if (result.url == null) {
                  await selectLocalFile(source.platform, source.category);
                } else {
                  await syncSource(source, result.url!);
                }
              },
      );
    }

    final sortedSources = useMemoized(
      () => sourceSorter(configProvider.config.sources),
      [configProvider.config.sources],
    );

    final tiles = useMemoized(() {
      List<Widget> result = [];
      Platform? lastPlatform;

      for (var source in sortedSources) {
        if (lastPlatform != null && lastPlatform != source.platform) {
          result.add(const Divider());
        }

        result.add(buildSourceTile(source));
        lastPlatform = source.platform;
      }

      return result;
    }, [sortedSources]);

    Future<void> updateHmacKey(String hmacKey) async => configProvider
        .updateConfig(configProvider.config.copyWith(hmacKey: hmacKey));

    Future<void> resetConfig() async {
      await Hive.box<Content>(psvBoxName).clear();
      await Hive.box<Content>(pspBoxName).clear();
      await Hive.box<Content>(psmBoxName).clear();
      await Hive.box<Content>(psxBoxName).clear();
      await Hive.box<Content>(ps3BoxName).clear();
      await Hive.box<DownloadItem>(downloadBoxName).clear();
      await configProvider.resetConfig();
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.settings), forceMaterialTransparency: true),
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
              title: Text(t.pkg2zip_output_mode),
              subtitle:
                  configProvider.config.pkg2zipOutputMode ==
                      Pkg2zipOutputMode.folder
                  ? Text(t.extract_to_folder)
                  : Text(t.convert_to_zip),
              onTap: () => showPkg2zipOutputModeDialog(context),
            ),
            ListTile(
              title: Text(t.hmac_key),
              subtitle: configProvider.config.hmacKey == null
                  ? null
                  : Text(configProvider.config.hmacKey!),
              onTap: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(t.hmac_key),
                  content: TextField(controller: hmacKeyController),
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
                      child: Text(t.confirm),
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
