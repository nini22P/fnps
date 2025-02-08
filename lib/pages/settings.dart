import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/config.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/utils/get_localizations.dart';
import 'package:vita_dl/utils/tsv_to_contents.dart';
import 'package:vita_dl/utils/uri.dart';

class Settings extends HookWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    final t = getLocalizations(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    Config config = configProvider.config;

    final appBox = Hive.box<Content>(appBoxName);
    final dlcBox = Hive.box<Content>(dlcBoxName);
    final themeBox = Hive.box<Content>(themeBoxName);

    final TextEditingController hmacKeyController =
        TextEditingController(text: config.hmacKey);

    Future<void> updateSource(
      ContentType contentType,
      SourceType sourceType,
      String url,
      DateTime updateTime,
    ) async {
      switch (contentType) {
        case ContentType.app:
          configProvider.updateConfig(configProvider.config.copyWith(
              app: Source(type: sourceType, updateTime: updateTime, url: url)));
          break;
        case ContentType.dlc:
          configProvider.updateConfig(configProvider.config.copyWith(
              dlc: Source(type: sourceType, updateTime: updateTime, url: url)));
          break;
        case ContentType.theme:
          configProvider.updateConfig(configProvider.config.copyWith(
              theme:
                  Source(type: sourceType, updateTime: updateTime, url: url)));
          break;
        default:
          break;
      }
    }

    Future<void> updateHmacKey(String hmacKey) async => configProvider
        .updateConfig(configProvider.config.copyWith(hmacKey: hmacKey));

    Future<void> pickTsvFile(ContentType type) async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tsv', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        String filePath = result.files.single.path!;
        final contents = await tsvToContents(filePath, type);
        switch (type) {
          case ContentType.app:
            await appBox.clear();
            await appBox.addAll(contents);
            break;
          case ContentType.dlc:
            await dlcBox.clear();
            await dlcBox.addAll(contents);
            break;
          case ContentType.theme:
            await themeBox.clear();
            await themeBox.addAll(contents);
            break;
          default:
            break;
        }
        await updateSource(type, SourceType.local, '', DateTime.now().toUtc());
      }
    }

    Future<void> resetConfig() async {
      await appBox.clear();
      await dlcBox.clear();
      await themeBox.clear();
      await configProvider.resetConfig();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: Text(t.updateAppList),
              subtitle: config.app.updateTime == null
                  ? const Text('')
                  : Text(config.app.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(ContentType.app),
            ),
            ListTile(
              title: Text(t.updateDLCList),
              subtitle: config.dlc.updateTime == null
                  ? const Text('')
                  : Text(config.dlc.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(ContentType.dlc),
            ),
            ListTile(
              title: Text(t.updateThemeList),
              subtitle: config.theme.updateTime == null
                  ? const Text('')
                  : Text(config.theme.updateTime!
                      .toLocal()
                      .toIso8601String()
                      .replaceAll('T', ' ')
                      .split('.')
                      .first),
              onTap: () => pickTsvFile(ContentType.theme),
            ),
            ListTile(
              title: Text(t.hmacKey),
              subtitle: config.hmacKey == null ? null : Text(config.hmacKey!),
              onTap: () => showDialog<String>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(t.hmacKey),
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
              title: Text(t.resetConfig),
              subtitle: Text(t.resetConfigSub),
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
