import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';
import 'package:path/path.dart' as p;

class Aria2Config {
  final int port;
  final String? secret;

  Aria2Config({required this.port, this.secret});
}

final _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(milliseconds: 500),
    receiveTimeout: const Duration(milliseconds: 500),
  ),
);

int _requestId = 0;

Future<dynamic> _aria2Request(
  Aria2Config config,
  String method, {
  List<dynamic>? params,
}) async {
  final port = config.port;
  final secret = config.secret;

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
    if (response.statusCode == 200) {
      return response.data;
    }
  } catch (e) {
    if (method != 'aria2.getVersion') {
      logger('Aria2 RPC Error ($method): $e');
    }
  }
  return null;
}

Future<bool> checkAria2(Aria2Config config) async {
  final data = await _aria2Request(config, 'aria2.getVersion');
  return data != null;
}

Future<void> stopAria2(Aria2Config config) async {
  if (await checkAria2(config)) {
    await _aria2Request(config, 'aria2.shutdown');
    logger('Aria2 shutdown command sent.');
  }
}

Future<void> startAria2() async {
  final confPath = await copyAria2Conf();
  final config = await getAria2Config(confPath);

  final port = config.port;

  if (await checkAria2(config)) {
    logger('Aria2 already running: port $port');
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
    logger('Aria2 started: port $port');
  } catch (e) {
    logger('Aria2 start failed: $e');
  }
}

Future<List<String>> copyAria2Conf() async {
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

Future<Aria2Config> getAria2Config(List<String> confPath) async {
  final file = File(pathJoin(confPath));
  final contents = await file.readAsString();
  final lines = contents.split('\n');

  int port = 7650;
  String? secret;

  for (final line in lines) {
    if (line.startsWith('rpc-listen-port=')) {
      port = int.parse(line.split('=').last);
    } else if (line.startsWith('rpc-secret=')) {
      secret = line.split('=').last;
    }
  }

  return Aria2Config(port: port, secret: secret);
}
