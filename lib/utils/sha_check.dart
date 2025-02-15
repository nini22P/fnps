import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:fnps/utils/logger.dart';

Future<bool> sha256Check(String filePath, String expectedSha256) async {
  final List<int> bytes = await File(filePath).readAsBytes();

  final Digest digest = sha256.convert(bytes);

  final String calculatedSha256 = digest.toString();

  logger('Calculated SHA256: $calculatedSha256');
  logger('Expected SHA256: $expectedSha256');

  return calculatedSha256.toLowerCase() == expectedSha256.toLowerCase();
}

Future<bool> sha1Check(String filePath, String expectedSha1) async {
  final file = File(filePath);

  final RandomAccessFile raf = await file.open();
  final int fileLength = await file.length();

  if (fileLength <= 32) {
    throw Exception('File is too small to calculate SHA-1 hash.');
  }

  final List<int> bytes = await raf.read(fileLength - 32);
  await raf.close();

  final Digest digest = sha1.convert(bytes);
  final String calculatedSha1 = digest.toString();

  logger('Calculated SHA1: $calculatedSha1');
  logger('Expected SHA1: $expectedSha1');

  return calculatedSha1.toLowerCase() == expectedSha1.toLowerCase();
}

Future<bool> _sha256CheckWrapper(List<String> args) {
  return sha256Check(args[0], args[1]).then((value) => value);
}

Future<bool> _sha1CheckWrapper(List<String> args) {
  return sha1Check(args[0], args[1]).then((value) => value);
}

Future<bool> computeSha256Check(String filePath, String expectedSha256) async {
  return await compute(_sha256CheckWrapper, [filePath, expectedSha256]);
}

Future<bool> computeSha1Check(String filePath, String expectedSha1) async {
  return await compute(_sha1CheckWrapper, [filePath, expectedSha1]);
}
