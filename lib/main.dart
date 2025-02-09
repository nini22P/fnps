import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:vita_dl/hive/hive_box_names.dart';
import 'package:vita_dl/models/download_item.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/pages/content_page/content_page.dart';
import 'package:vita_dl/pages/home_page.dart';
import 'package:vita_dl/downloader/downloader.dart';
import 'package:vita_dl/utils/path.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');

  final configPath = await getConfigPath();

  await Hive.initFlutter(pathJoin(configPath));

  Hive.registerAdapter(ContentAdapter());
  Hive.registerAdapter(ContentTypeAdapter());
  Hive.registerAdapter(DownloadItemAdapter());
  Hive.registerAdapter(DownloadStatusAdapter());
  Hive.registerAdapter(ExtractStatusAdapter());

  await Hive.openBox<DownloadItem>(downloadBoxName);
  await Hive.openBox<Content>(appBoxName);
  await Hive.openBox<Content>(dlcBoxName);
  await Hive.openBox<Content>(themeBoxName);

  await Downloader.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ConfigProvider()..loadConfig(),
      child: const VitaDL(),
    ),
  );
}

class VitaDL extends HookWidget {
  const VitaDL({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitaDL',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(title: 'VitaDL'),
      onGenerateRoute: (settings) {
        if (settings.name == '/content') {
          final content = settings.arguments as Content;
          return MaterialPageRoute(
            builder: (context) {
              return ContentPage(content: content);
            },
          );
        }
        return null;
      },
    );
  }
}
