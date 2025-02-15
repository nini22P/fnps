import 'package:flutter/services.dart';
import 'package:fnps/globals.dart' as globals;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/hive_registrar.g.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/pages/content_page/content_page.dart';
import 'package:fnps/pages/home_page.dart';
import 'package:fnps/downloader/downloader.dart';
import 'package:fnps/utils/path.dart';
import 'package:fnps/utils/platform.dart';
import 'package:fnps/utils/request_storage_permission.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');

  final configPath = await getConfigPath();

  await Hive.initFlutter(pathJoin(configPath));

  Hive.registerAdapters();

  await Hive.openBox<DownloadItem>(downloadBoxName);
  await Hive.openBox<Content>(psvBoxName);
  await Hive.openBox<Content>(pspBoxName);

  await Downloader.instance.init();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ConfigProvider()..loadConfig(),
      child: const FNPS(),
    ),
  );
}

class FNPS extends HookWidget {
  const FNPS({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      () async {
        globals.storagePermissionStatus = isAndroid
            ? await isAndroid11OrHigher()
                ? await Permission.manageExternalStorage.status
                : await Permission.storage.status
            : PermissionStatus.granted;
      }();
      return null;
    }, []);

    useEffect(() {
      if (isAndroid || isIOS) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ));
      }
      return null;
    }, []);

    return MaterialApp(
      title: 'FNPS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomePage(title: 'FNPS'),
      onGenerateRoute: (settings) {
        if (settings.name == '/content') {
          final props = settings.arguments as ContentPageProps;
          return MaterialPageRoute(
            builder: (context) {
              return ContentPage(props: props);
            },
          );
        }
        return null;
      },
    );
  }
}
