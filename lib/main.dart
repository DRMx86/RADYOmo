import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.phradio.channel.audio',
    androidNotificationChannelName: 'Radio playback',
    androidNotificationOngoing: true,
  );
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const RadioApp());
}

class Station {
  final String name;
  final String freq;
  final String url;
  final Color color;
  const Station(this.name, this.freq, this.url, this.color);
}

const stations = <Station>[
  Station('Monster Radio', 'RX 93.1',
      'https://in-icecast.eradioportal.com:8443/monsterrrx', Color(0xFFE53935)),
  // NOTE: ".m3u" removed - the player needs the raw stream, not a playlist file.
  Station('Win Radio', '91.5',
      'https://stream.zeno.fm/2ss1hgnu6hhvv', Color(0xFF1E88E5)),
  Station('Magic', '89.9',
      'https://stream-161.zeno.fm/sh37pvfd938uv', Color(0xFFFB8C00)),
];

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PH Radio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const PlayerPage(),
      );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = AudioPlayer();
  final _pageController = PageController(viewportFraction: 0.78);
  int _index = 0;
  int? _loadedIndex;

  @override
  void initState() {
    super.initState();
    _player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play this station. Check your connection.')),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load(int i) async {
    final s = stations[i];
    _loadedIndex = i;
    try {
      await _player.setAudioSource(AudioSource.uri(
        Uri.parse(s.url),
        tag: MediaItem(
          id: s.url,
          title: s.name,
          artist: s.freq,
          album: 'Live Radio',
        ),
      ));
      _player.play();
    } catch (_) {
      _loadedIndex = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to play this station.')),
        );
      }
    }
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      // Live stream: stop so resuming goes back to "live", not stale buffer.
      await _player.stop();
      _loadedIndex = null;
    } else {
      await _load(_index);
    }
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (_player.playing) _load(i); // keep playing on the new station
  }

  @override
  Widget build(BuildContext context) {
    final station = stations[_index];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [station.color.withOpacity(0.55), const Color(0xFF121212)],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text('LIVE RADIO',
                  style: TextStyle(letterSpacing: 3, fontSize: 12, color: Colors.white70)),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: stations.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) => AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double page = _index.toDouble();
                      if (_pageController.hasClients &&
                          _pageController.position.haveDimensions) {
                        page = _pageController.page ?? page;
                      }
                      final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
                      return Center(
                        child: Transform.scale(
                          scale: 0.82 + 0.18 * t,
                          child: Opacity(opacity: 0.45 + 0.55 * t, child: child),
                        ),
                      );
                    },
                    child: _StationCard(station: stations[i]),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  stations.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? Colors.white : Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snap) {
                  final st = snap.data;
                  final busy = st?.processingState == ProcessingState.loading ||
                      st?.processingState == ProcessingState.buffering;
                  final playing = st?.playing ?? false;
                  return _PlayButton(playing: playing, busy: busy && playing || (busy && _loadedIndex != null), onTap: _toggle);
                },
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final Station station;
  const _StationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [station.color, station.color.withOpacity(0.55)],
          ),
          boxShadow: [
            BoxShadow(
              color: station.color.withOpacity(0.45),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radio, size: 56, color: Colors.white70),
            const SizedBox(height: 20),
            Text(station.freq,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(station.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final bool busy;
  final VoidCallback onTap;
  const _PlayButton({required this.playing, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: Color(0xFF1DB954), // Spotify green
          shape: BoxShape.circle,
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
              )
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 46, color: Colors.black),
      ),
    );
  }
}
