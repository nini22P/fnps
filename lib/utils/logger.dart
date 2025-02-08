import 'dart:developer';
import 'package:flutter/foundation.dart';

void logger(String message, {Object? error}) {
  if (kDebugMode) {
    log(message, error: error);
  }
}
