import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';

Future<String?> getNativeLibraryDir() async {
  if (!Platform.isAndroid) return null;
  const MethodChannel platformChannel = MethodChannel('mychannel');

  try {
    final String result =
        await platformChannel.invokeMethod('getNativeLibraryDir');
    return result;
  } on PlatformException catch (e) {
    log('Failed to get native library dir: ${e.message}');
    return null;
  }
}
