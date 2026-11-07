import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import 'player_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never let a stray async error take the app down.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('Unhandled: $error');
    return true;
  };

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.phradio.channel.audio',
      androidNotificationChannelName: 'Radio playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_notification',
    );
  } catch (_) {
    // App still opens even if background service fails to start.
  }

  // Audio focus: when another app (YouTube, Spotify, ...) starts playing,
  // pause instead of mixing or ducking. Pauses caused by focus loss are not
  // triggered by browsing or the home screen, so background play continues.
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const RadioApp());

  // After the first frame, so it can never delay or block startup (TV boxes).
  unawaited(_askNotificationPermission());
}

Future<void> _askNotificationPermission() async {
  try {
    await Permission.notification.request();
  } catch (_) {}
}

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  static final _theme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    focusColor: const Color(0x4DFFFFFF), // TV remote focus highlight
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RADYOmo',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        home: const PlayerPage(),
      );
}
