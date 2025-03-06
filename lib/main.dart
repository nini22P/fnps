import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fnps/theme.dart';
import 'package:fnps/utils/my_http_overrides.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fnps/hive/hive_box_names.dart';
import 'package:fnps/models/download_item.dart';
import 'package:fnps/provider/config_provider.dart';
import 'package:fnps/models/content.dart';
import 'package:fnps/pages/content_page/content_page.dart';
import 'package:fnps/pages/home_page.dart';
import 'package:fnps/downloader/downloader.dart';
import 'package:fnps/utils/path.dart';
import 'package:fnps/utils/platform.dart';

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();

  await dotenv.load(fileName: '.env');

  final configPath = await getConfigPath();

  await Hive.initFlutter(pathJoin(configPath));

  Hive.registerAdapter(PlatformAdapter());
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(RegionAdapter());
  Hive.registerAdapter(ContentAdapter());
  Hive.registerAdapter(DownloadStatusAdapter());
  Hive.registerAdapter(ExtractStatusAdapter());
  Hive.registerAdapter(DownloadItemAdapter());

  await Hive.openBox<DownloadItem>(downloadBoxName);
  await Hive.openBox<Content>(psvBoxName);
  await Hive.openBox<Content>(pspBoxName);
  await Hive.openBox<Content>(psmBoxName);
  await Hive.openBox<Content>(psxBoxName);
  await Hive.openBox<Content>(ps3BoxName);

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
      if (isAndroid || isIOS) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ));
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      return null;
    }, []);

    return DynamicColorBuilder(
      builder: (
        ColorScheme? lightDynamic,
        ColorScheme? darkDynamic,
      ) {
        final theme = getTheme(
          context: context,
          lightDynamic: lightDynamic,
          darkDynamic: darkDynamic,
        );

        return MaterialApp(
          title: 'FNPS',
          theme: theme.light,
          darkTheme: theme.dark,
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
      },
    );
  }
}
