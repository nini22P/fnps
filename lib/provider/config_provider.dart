import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vita_dl/utils/path.dart';
import '../models/config.dart';

class ConfigProvider with ChangeNotifier {
  Config _config = Config.initConfig;

  Config get config => _config;

  Future<List<String>> getConfigPath() async =>
      [...await getAppPath(), 'config', 'config.json'];

  Future<void> loadConfig() async {
    final file = File(pathJoin(await getConfigPath()));

    if (await file.exists()) {
      String contents = await file.readAsString();
      _config = Config.fromJson(json.decode(contents));
      notifyListeners();
    }
  }

  Future<void> saveConfig() async {
    final file = File(pathJoin(await getConfigPath()));
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
