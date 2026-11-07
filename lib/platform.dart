import 'package:flutter/services.dart';

/// Small bridge to the Android activity (see tool/patch_android.py).
const _channel = MethodChannel('radyomo/platform');

/// True when running on an Android TV / Google TV device.
Future<bool> isTv() async {
  try {
    return await _channel.invokeMethod<bool>('isTv') ?? false;
  } catch (_) {
    return false;
  }
}

/// Keeps the screen awake (prevents TV idle / screensaver / auto-standby).
Future<void> keepScreenOn(bool on) async {
  try {
    await _channel.invokeMethod<void>('keepScreenOn', on);
  } catch (_) {}
}
