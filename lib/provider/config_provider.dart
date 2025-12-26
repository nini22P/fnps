import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fnps/utils/path.dart';
import '../models/config.dart';

class ConfigProvider with ChangeNotifier {
  Config _config = Config.initConfig;

  Config get config => _config;

  Future<void> loadConfig() async {
    final file = File(pathJoin([...await getConfigPath(), 'config.json']));

    if (await file.exists()) {
      String contents = await file.readAsString();
      final config = Config.fromJson(json.decode(contents));
      _config = config.copyWith(
        sources: config.sources
            .map(
              (source) =>
                  source.syncStatus == SyncStatus.syncing ||
                      source.syncStatus == SyncStatus.queue
                  ? source.copyWith(
                      syncStatus: source.count > 0
                          ? SyncStatus.done
                          : SyncStatus.notSyncing,
                    )
                  : source,
            )
            .toList(),
      );
      notifyListeners();
    }
  }

  Future<void> saveConfig() async {
    final file = File(pathJoin([...await getConfigPath(), 'config.json']));
    await file.writeAsString(json.encode(_config.toJson()));
  }

  void updateConfig(Config config) {
    _config = config;
    saveConfig();
    notifyListeners();
  }

  Future<void> resetConfig() async {
    _config = Config.initConfig;
    saveConfig();
    notifyListeners();
  }
}
