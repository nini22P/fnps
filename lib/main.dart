import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:vita_dl/provider/config_provider.dart';
import 'package:vita_dl/models/content.dart';
import 'package:vita_dl/pages/content_page.dart';
import 'package:vita_dl/pages/home_page.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await dotenv.load(fileName: '.env');
  await FileDownloader().trackTasks();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ConfigProvider()..loadConfig(),
      child: const VitaDL(),
    ),
  );
}

class VitaDL extends StatelessWidget {
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
