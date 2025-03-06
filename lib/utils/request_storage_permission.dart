import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<PermissionStatus> requestStoragePermission() async {
  if (!Platform.isAndroid) {
    return PermissionStatus.granted;
  }
  if (await isAndroid11OrHigher()) {
    return await Permission.manageExternalStorage.request();
  } else {
    return await Permission.storage.request();
  }
}

Future<bool> isAndroid11OrHigher() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  return androidInfo.version.sdkInt >= 30;
}
