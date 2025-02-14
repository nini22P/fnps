import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/config.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/get_localizations.dart';
import 'package:vita_dl/utils/platform.dart';
import 'package:vita_dl/utils/request_storage_permission.dart';
import 'package:vita_dl/utils/tsv_to_contents.dart';
import 'package:vita_dl/utils/uri.dart';

class Settings extends HookWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    Config config = configProvider.config;

    final psvBox = Hive.box<Content>(psvBoxName);
    final pspBox = Hive.box<Content>(pspBoxName);

    final TextEditingController hmacKeyController =
        TextEditingController(text: config.hmacKey);

    Future<void> updateSource(
      Platform platform,
      Category category,
      SourceType sourceType,
      String url,
      DateTime updateTime,
    ) async {
      switch (platform) {
        case Platform.psv:
          switch (category) {
            case Category.game:
              configProvider.updateConfig(configProvider.config.copyWith(
                  psvGames: Source(
                type: sourceType,
                updateTime: updateTime,
                url: url,
              )));
              break;
            case Category.dlc:
              configProvider.updateConfig(configProvider.config.copyWith(
                  psvDLCs: Source(
                type: sourceType,
                updateTime: updateTime,
                url: url,
              )));
              break;
            case Category.theme:
              configProvider.updateConfig(configProvider.config.copyWith(
                  psvThemes: Source(
                type: sourceType,
                updateTime: updateTime,
                url: url,
              )));
              break;
            case Category.update:
              break;
            case Category.demo:
              configProvider.updateConfig(configProvider.config.copyWith(
                  psvDEMOs: Source(
                type: sourceType,
                updateTime: updateTime,
                url: url,
              )));
              break;
          }
          break;
        case Platform.psp:
          switch (category) {
            case Category.game:
              configProvider.updateConfig(configProvider.config.copyWith(
                  pspGames: Source(
                type: sourceType,
                updateTime: updateTime,
                url: url,
              )));
              break;
            case Category.dlc:
              configProvider.updateConfig(configProvider.config.copyWith(
                  pspDLCs: Source(
                type: sourceType,
                updateTime: updateTime,
                url: url,
              )));
              break;
            case Category.theme:
            case Category.update:
            case Category.demo:
              break;
          }
          break;
        default:
          break;
      }
    }

    Future<void> updateHmacKey(String hmacKey) async => configProvider
        .updateConfig(configProvider.config.copyWith(hmacKey: hmacKey));

    Future<void> pickTsvFile(Platform platform, Category category) async {
      String? content;

      if (isAndroid) {
        await requestStoragePermission();
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
          default:
            break;
        }
        await updateSource(
            platform, category, SourceType.local, '', DateTime.now().toUtc());
      }
    }

    Future<void> resetConfig() async {
      await psvBox.clear();
      await pspBox.clear();
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
              title: Text(t.update_psv_game_list),
              subtitle: config.psvGames.updateTime == null
                  ? const Text('')
                  : Text(config.psvGames.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(Platform.psv, Category.game),
            ),
            ListTile(
              title: Text(t.update_psv_dlc_list),
              subtitle: config.psvDLCs.updateTime == null
                  ? const Text('')
                  : Text(config.psvDLCs.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(Platform.psv, Category.dlc),
            ),
            ListTile(
              title: Text(t.update_psv_theme_list),
              subtitle: config.psvThemes.updateTime == null
                  ? const Text('')
                  : Text(config.psvThemes.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(Platform.psv, Category.theme),
            ),
            ListTile(
              title: Text(t.update_psv_demo_list),
              subtitle: config.psvDEMOs.updateTime == null
                  ? const Text('')
                  : Text(config.psvDEMOs.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(Platform.psv, Category.demo),
            ),
            const Divider(),
            ListTile(
              title: Text(t.update_psp_game_list),
              subtitle: config.pspGames.updateTime == null
                  ? const Text('')
                  : Text(config.pspGames.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(Platform.psp, Category.game),
            ),
            ListTile(
              title: Text(t.update_psp_dlc_list),
              subtitle: config.pspDLCs.updateTime == null
                  ? const Text('')
                  : Text(config.pspDLCs.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(Platform.psp, Category.dlc),
            ),
            const Divider(),
            ListTile(
              title: Text(t.hmac_key),
              subtitle: config.hmacKey == null ? null : Text(config.hmacKey!),
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
              title: const Text('VitaDL'),
              subtitle: const Text('A PSVita application downloader'),
              onTap: () => launchURL('https://github.com/nini22P/VitaDL'),
            ),
          ],
        ),
      ),
    );
  }
}
