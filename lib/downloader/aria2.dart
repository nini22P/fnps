import 'dart:io';
import 'dart:convert';
import 'package:fnps/utils/logger.dart';
import 'package:fnps/utils/path.dart';
import 'package:path/path.dart' as p;

final String userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.5481.178 Safari/537.36';

Future<void> startAria2({int port = 7650, String? secret}) async {
  final List<String> aria2cPathList = await getAria2cPath();
  final String aria2cExecutable = p.joinAll(aria2cPathList);

  final List<String> args = [
    '--enable-rpc',
    '--rpc-listen-all=false',
    '--rpc-listen-port=${port.toString()}',
    '--continue=true',
    '--max-connection-per-server=16',
    '--split=16',
    '--min-split-size=10M',
    '--max-overall-download-limit=0',
    '--file-allocation=none',
    '--enable-mmap=true',
    '--disk-cache=64M',
    '--max-tries=5',
    '--retry-wait=3',
    '--timeout=60',
    '--connect-timeout=30',
    '--max-file-not-found=5',
    '--auto-file-renaming=false',
    '--user-agent=$userAgent',
    '--check-certificate=false',
    '--disable-ipv6=true',
    '--log-level=warn',
  ];

  if (secret != null && secret.isNotEmpty) {
    args.add('--rpc-secret=$secret');
  }

  if (!Platform.isWindows) {
    args.add('-D');
  }

  try {
    final process = await Process.start(
      aria2cExecutable,
      args,
      mode: ProcessStartMode.normal,
    );

    process.stdout.transform(utf8.decoder).listen((data) {
      // logger('Aria2 STDOUT: $data');
    });
    process.stderr.transform(utf8.decoder).listen((data) {
      logger('Aria2 STDERR: $data');
    });

    logger('Aria2 started: http://localhost:$port/jsonrpc');
  } catch (e) {
    logger('Aria2 start failed: $e');
  }
}
