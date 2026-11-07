import 'package:flutter/material.dart';

class Station {
  const Station(this.name, this.freq, this.url, this.color);

  final String name;
  final String freq;
  final String url;
  final Color color;

  /// Softer shade used for gradients.
  Color get soft => color.withAlpha(140);
}

const stations = <Station>[
  Station('Monster Radio', 'RX 93.1',
      'https://in-icecast.eradioportal.com:8443/monsterrrx', Color(0xFFE53935)),
  Station('Win Radio', '91.5', 'https://stream.zeno.fm/2ss1hgnu6hhvv',
      Color(0xFF1E88E5)),
  Station('Magic', '89.9', 'https://stream-161.zeno.fm/sh37pvfd938uv',
      Color(0xFFFB8C00)),
];
