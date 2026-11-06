import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request notification permission for Android 13+
  await Permission.notification.request();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.phradio.channel.audio',
      androidNotificationChannelName: 'Radio playback',
      androidNotificationOngoing: true,
    );
  } catch (_) {
    // App still opens even if background service fails to start.
  }
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
  Station('Win Radio', '91.5', 'https://stream.zeno.fm/2ss1hgnu6hhvv',
      Color(0xFF1E88E5)),
  Station('Magic', '89.9', 'https://stream-161.zeno.fm/sh37pvfd938uv',
      Color(0xFFFB8C00)),
];

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PH Radio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          // TV REMOTE FOCUS HIGHLIGHT
          focusColor: Colors.white.withOpacity(0.3),
        ),
        home: const PlayerPage(),
      );
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final AudioPlayer _player;
  int _index = 0;
  int _dir = 1;
  bool _showList = true;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer(
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    _setupAudioSources();
    _setupVolumeListener();

    _player.currentIndexStream.listen((index) {
      if (index != null && index != _index) {
        setState(() {
          _dir = index > _index ? 1 : -1;
          _index = index;
        });
      }
    });

    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object error, StackTrace stackTrace) {
        _snack('Playback error. Check your connection.');
      },
    );
  }

  void _setupVolumeListener() async {
    _volume = await VolumeController.instance.getVolume();
    VolumeController.instance.addListener((volume) {
      if (mounted) {
        setState(() => _volume = volume);
      }
    });
  }

  Future<void> _setupAudioSources() async {
    try {
      final playlist = ConcatenatingAudioSource(
        children: stations
            .map((s) => AudioSource.uri(
                  Uri.parse(s.url),
                  tag: MediaItem(
                    id: s.url,
                    title: s.name,
                    artist: s.freq,
                    album: 'Live Radio',
                  ),
                ))
            .toList(),
      );

      await _player.setAudioSource(playlist, initialIndex: _index);
    } catch (_) {
      _snack('Unable to initialize stations.');
    }
  }

  @override
  void dispose() {
    VolumeController.instance.removeListener();
    _player.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.audioSource == null) {
        await _setupAudioSources();
      }
      _player.play();
    }
  }

  void _select(int i, {bool fromList = false}) {
    if (i < 0 || i >= stations.length) return; // Prevent out-of-bounds
    setState(() {
      _dir = i >= _index ? 1 : -1;
      _index = i;
      if (fromList) _showList = false;
    });

    _player.seek(Duration.zero, index: i);
    if (!_player.playing) _player.play();
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -300 && _index < stations.length - 1) _select(_index + 1);
    if (v > 300 && _index > 0) _select(_index - 1);
  }

  Widget _buildVolumeSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.volume_down, color: Colors.white54, size: 20),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _volume,
                onChanged: (v) {
                  setState(() => _volume = v);
                  VolumeController.instance.setVolume(v);
                },
              ),
            ),
          ),
          const Icon(Icons.volume_up, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
          onPressed: () => _player.seekToPrevious(),
        ),
        const SizedBox(width: 16),
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snap) {
            final s = snap.data;
            final loading = s?.processingState == ProcessingState.loading ||
                s?.processingState == ProcessingState.buffering;
            return _PlayButton(
              playing: s?.playing ?? false,
              busy: loading,
              onTap: _toggle,
            );
          },
        ),
        const SizedBox(width: 16),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: () => _player.seekToNext(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = stations[_index];
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // PopScope handles the physical Back button on phones and TV remotes
    return PopScope(
      canPop: _showList, 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If back is pressed while on the player, show the station list
        setState(() => _showList = true);
      },
      child: CallbackShortcuts(
        bindings: {
          // Map TV Remote directional pad to station changes
          // FIXED: Wrapped LogicalKeyboardKey in SingleActivator
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (!_showList) _select(_index - 1);
          },
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (!_showList) _select(_index + 1);
          },
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause): _toggle,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [st.color.withOpacity(0.6), const Color(0xFF121212)],
                      stops: const [0, 0.7],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            const SizedBox(width: 48),
                            const Expanded(
                              child: Center(
                                child: Text('LIVE RADIO',
                                    style: TextStyle(
                                        letterSpacing: 3,
                                        fontSize: 12,
                                        color: Colors.white70)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.queue_music_rounded),
                              onPressed: () => setState(() => _showList = true),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: isLandscape
                            ? _buildLandscapeLayout(st)
                            : _buildPortraitLayout(st),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showList,
                    child: AnimatedSlide(
                      offset: _showList ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        color: const Color(0xFF121212),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 28),
                                const Text('Select Station',
                                    style: TextStyle(
                                        fontSize: 28, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                const Text('Choose a radio station to start listening',
                                    style: TextStyle(color: Colors.white54)),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: stations.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, i) => _StationTile(
                                      station: stations[i],
                                      selected: i == _index,
                                      onTap: () => _select(i, fromList: true),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _showList = false),
                                  child: const Text('Back to player'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(Station st) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(_index);
                  final begin =
                      Offset(incoming ? _dir.toDouble() : -_dir.toDouble(), 0);
                  return SlideTransition(
                    position:
                        Tween<Offset>(begin: begin, end: Offset.zero)
                            .animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: _StationCard(key: ValueKey(_index), station: st),
              ),
            ),
          ),
        ),
        _buildDots(),
        const SizedBox(height: 16),
        _buildVolumeSlider(),
        const SizedBox(height: 16),
        _buildControls(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLandscapeLayout(Station st) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Align(
            alignment: Alignment.centerLeft, 
            child: Padding(
              padding: const EdgeInsets.only(left: 40.0), 
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: _onSwipe,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) {
                    final incoming = child.key == ValueKey(_index);
                    final begin =
                        Offset(incoming ? _dir.toDouble() : -_dir.toDouble(), 0);
                    return SlideTransition(
                      position:
                          Tween<Offset>(begin: begin, end: Offset.zero)
                              .animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: _StationCard(
                    key: ValueKey(_index),
                    station: st,
                    isLandscape: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDots(),
              const SizedBox(height: 24),
              _buildVolumeSlider(),
              const SizedBox(height: 24),
              _buildControls(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDots() {
    return Row(
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
    );
  }
}

class _StationTile extends StatelessWidget {
  final Station station;
  final bool selected;
  final VoidCallback onTap;
  const _StationTile(
      {required this.station, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [station.color, station.color.withOpacity(0.5)],
            ),
            border: selected
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(station.freq,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded,
                  size: 38, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final Station station;
  final bool isLandscape;

  const _StationCard({
    super.key,
    required this.station,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final w = isLandscape ? screenHeight * 0.6 : screenWidth * 0.78;
    final h = isLandscape ? screenHeight * 0.7 : w * 1.2;

    return Container(
      width: w,
      height: h,
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
          Icon(Icons.radio,
              size: isLandscape ? 40 : 56, color: Colors.white70),
          SizedBox(height: isLandscape ? 12 : 20),
          Text(station.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLandscape ? 28 : 34,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          Text(station.freq,
              style: TextStyle(
                fontSize: isLandscape ? 16 : 20,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool playing;
  final bool busy;
  final VoidCallback onTap;
  const _PlayButton(
      {required this.playing, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: Color(0xFF1DB954),
          shape: BoxShape.circle,
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.black),
              )
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 46, color: Colors.black),
      ),
    );
  }
}
