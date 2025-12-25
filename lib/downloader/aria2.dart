import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:fnps/models/aria2.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';
import 'package:path/path.dart' as p;

class Aria2 {
  Aria2._privateConstructor();

  static final Aria2 _instance = Aria2._privateConstructor();

  static Aria2 get instance => _instance;

  int _requestId = 0;
  Aria2Config? config;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  Future<dynamic> request(String method, {List<dynamic>? params}) async {
    if (config == null) {
      logger('Aria2 Error: Config not loaded');
      return null;
    }

    final port = config!.port;
    final secret = config!.secret;
    final url = 'http://localhost:$port/jsonrpc';

    final List<dynamic> finalParams = [];
    if (secret != null && secret.isNotEmpty) {
      finalParams.add('token:$secret');
    }
    if (params != null) {
      finalParams.addAll(params);
    }

    final data = {
      "jsonrpc": "2.0",
      "id": "fnps_${_requestId++}",
      "method": method,
      "params": finalParams,
    };

    try {
      final response = await _dio.post(url, data: data);
      if (response.statusCode == 200 && response.data != null) {
        final decoded = jsonDecode(response.data);
        if (decoded != null && decoded['result'] != null) {
          return decoded;
        }
      }
    } catch (e) {
      if (method != 'aria2.getVersion') {
        logger('Aria2 RPC Error ($method): $e');
      }
    }
    return null;
  }

  Future<bool> check() async {
    final data = await request('aria2.getVersion');
    return data != null;
  }

  Future<void> init() async {
    final confPath = await _copyConf();
    config = await _getConf(confPath);

    if (await check()) {
      logger('Aria2 already running: port ${config!.port}');
      return;
    }

    final List<String> aria2cPathList = await getAria2cPath();
    final String aria2cExecutable = p.joinAll(aria2cPathList);

    final List<String> args = [
      '--conf-path=${pathJoin(confPath)}',
      '--stop-with-process=${pid.toString()}',
      '--enable-rpc',
    ];

    if (!Platform.isWindows) {
      args.add('-D');
    }

    try {
      await Process.start(
        aria2cExecutable,
        args,
        mode: ProcessStartMode.detached,
      );
      logger('Aria2 started: port ${config!.port}');
    } catch (e) {
      logger('Aria2 start failed: $e');
    }
  }

  Future<void> destroy() async {
    if (await check()) {
      await request('aria2.shutdown');
      logger('Aria2 shutdown command sent.');
    }
  }

  Future<String> addUri(String uri, String dir, String out) async {
    final dynamic data = await request(
      'aria2.addUri',
      params: [
        [uri],
        {'dir': dir, 'out': out},
      ],
    );
    return data['result'];
  }

  Future<String> remove(String gid) async {
    final dynamic data = await request('aria2.remove', params: [gid]);
    return data['result'];
  }

  Future<String> pause(String gid) async {
    final dynamic data = await request('aria2.pause', params: [gid]);
    return data['result'];
  }

  Future<String> unpause(String gid) async {
    final dynamic data = await request('aria2.unpause', params: [gid]);
    return data['result'];
  }

  Future<bool> removeDownloadResult(String gid) async {
    final dynamic data = await request(
      'aria2.removeDownloadResult',
      params: [gid],
    );
    return data['result'] == 'OK';
  }

  Future<Aria2GlobalStat> getGlobalStat() async {
    final dynamic data = await request('aria2.getGlobalStat');
    return Aria2GlobalStat.fromJson(data['result']);
  }

  Future<List<Aria2Status>> tellActive() async {
    final dynamic data = await request('aria2.tellActive');
    return (data['result'] as List)
        .map((e) => Aria2Status.fromJson(e))
        .toList();
  }

  Future<List<Aria2Status>> tellWaiting() async {
    final dynamic data = await request(
      'aria2.tellWaiting',
      params: [-1, 10000],
    );
    return (data['result'] as List)
        .map((e) => Aria2Status.fromJson(e))
        .toList();
  }

  Future<List<Aria2Status>> tellStopped() async {
    final dynamic data = await request(
      'aria2.tellStopped',
      params: [-1, 10000],
    );
    return (data['result'] as List)
        .map((e) => Aria2Status.fromJson(e))
        .toList();
  }

  Future<List<String>> _copyConf() async {
    const assetsConfPath = 'assets/aria2.conf';
    final List<String> configPath = await getConfigPath();
    final List<String> confPath = [...configPath, 'aria2.conf'];

    final file = File(pathJoin(confPath));

    if (await file.exists()) {
      return confPath;
    }

    final byteData = await rootBundle.load(assetsConfPath);
    final buffer = byteData.buffer.asUint8List();
    await file.writeAsBytes(buffer);
    logger('Aria2 config copied to: ${p.joinAll(confPath)}');
    return confPath;
  }

  Future<Aria2Config> _getConf(List<String> confPath) async {
    final file = File(pathJoin(confPath));
    final contents = await file.readAsString();
    final lines = contents.split('\n');

    int port = 7650;
    String? secret;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('rpc-listen-port=')) {
        port = int.parse(trimmed.split('=').last);
      } else if (trimmed.startsWith('rpc-secret=')) {
        secret = trimmed.split('=').last;
      }
    }

    return Aria2Config(port: port, secret: secret);
  }
}
