import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:vita_dl/utils/storage.dart';
import '../model/config_model.dart';

class ConfigProvider with ChangeNotifier {
  Config _config = Config.fromJson(Config.initConfig);

  Config get config => _config;

  Future<String> getConfigPath() async =>
      join(await getAppPath(), 'config', 'config.json');

  Future<void> loadConfig() async {
    final file = File(await getConfigPath());

    if (await file.exists()) {
      String contents = await file.readAsString();
      _config = Config.fromJson(json.decode(contents));
      notifyListeners();
    }
  }

  Future<void> saveConfig() async {
    final file = File(await getConfigPath());
    await file.writeAsString(json.encode(_config.toJson()));
  }

  void updateConfig(Config config) {
    _config = config;
    saveConfig();
    notifyListeners();
  }

  Future<void> resetConfig() async {
    _config = Config.fromJson(Config.initConfig);
    saveConfig();
    notifyListeners();
  }
}
