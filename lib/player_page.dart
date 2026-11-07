import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:volume_controller/volume_controller.dart';

import 'platform.dart' as platform;
import 'stations.dart';
import 'widgets.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final AudioPlayer _player;
  final _volume = ValueNotifier<double>(1.0);

  // Explicit focus targets so the TV remote always lands on something after
  // switching between the station list and the now-playing screen.
  final _playFocus = FocusNode(debugLabel: 'play');
  final _tileFocus = List.generate(
      stations.length, (i) => FocusNode(debugLabel: 'station-$i'));

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<bool>? _playingSub;
  bool _isTv = false;

  int _index = 0;
  int _dir = 1;
  bool _showList = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer(
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    // Wrap-around playlist keeps previous / play-pause / next all visible in
    // the swipe-down notification. Does not change streams or audio output.
    _player.setLoopMode(LoopMode.all);

    _setupAudioSources();
    _setupVolume();

    _indexSub = _player.currentIndexStream.listen((i) {
      if (i != null) _setIndex(i);
    });
    _eventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace s) =>
          _snack('Playback error. Check your connection.'),
    );

    // TV only: keep the screen awake while actually playing, so the TV's
    // idle/screensaver timers don't kick in during use. Phones are untouched.
    platform.isTv().then((tv) {
      _isTv = tv;
      if (tv) {
        platform.keepScreenOn(_player.playing);
        // Always draw the remote-control focus highlight on TV.
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
      }
    });
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_guardFocus);
    _playingSub = _player.playingStream.listen((playing) {
      if (_isTv) platform.keepScreenOn(playing);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tileFocus[_index].requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_guardFocus);
    _indexSub?.cancel();
    _eventSub?.cancel();
    _playingSub?.cancel();
    VolumeController.instance.removeListener();
    _player.dispose();
    _volume.dispose();
    _playFocus.dispose();
    for (final n in _tileFocus) {
      n.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- audio

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

  Future<void> _setupVolume() async {
    try {
      final v = await VolumeController.instance.getVolume();
      if (mounted) _volume.value = v;
    } catch (_) {}
    VolumeController.instance.addListener((v) {
      if (mounted) _volume.value = v;
    });
  }

  void _play() => _player.play().catchError((_) {});

  Future<void> _toggle() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.audioSource == null) await _setupAudioSources();
        _play();
      }
    } catch (_) {
      _snack('Playback error. Check your connection.');
    }
  }

  Future<void> _select(int i, {bool closeList = false}) async {
    final n = stations.length;
    if (i < 0 || i >= n) return;
    _setIndex(i);
    if (closeList) _openList(false);
    try {
      if (_player.audioSource == null) {
        await _setupAudioSources();
      } else if (_player.currentIndex != i) {
        await _player.seek(Duration.zero, index: i);
      }
      if (!_player.playing) _play();
    } catch (_) {
      _snack('Unable to switch station.');
    }
  }

  void _step(int delta) {
    final n = stations.length;
    _select((_index + delta + n) % n);
  }

  // ----------------------------------------------------------- focus

  /// The control that should hold focus for the layer currently shown.
  FocusNode get _defaultFocus => _showList ? _tileFocus[_index] : _playFocus;

  /// True when focus sits on a real, attached control (not on nothing / a scope).
  bool get _hasFocusedControl {
    final f = FocusManager.instance.primaryFocus;
    return f != null &&
        f is! FocusScopeNode &&
        f.context != null &&
        f.canRequestFocus;
  }

  void _restoreFocus() {
    if (!mounted || _hasFocusedControl) return;
    _defaultFocus.requestFocus();
  }

  /// If focus got lost (long idle, screensaver, screen off/on...), the next
  /// remote key press puts it back on a button instead of doing nothing.
  bool _guardFocus(KeyEvent e) {
    if (e is! KeyDownEvent || _hasFocusedControl) return false;
    final keys = {
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.gameButtonA,
    };
    if (!keys.contains(e.logicalKey)) return false;
    _restoreFocus();
    return true; // this press only brings the highlight back
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFocus());
    }
  }

  // ------------------------------------------------------------------ ui

  /// Shortest visual direction to [i], also correct when wrapping around.
  int _dirTo(int i) {
    final n = stations.length;
    return (i - _index + n) % n <= n / 2 ? 1 : -1;
  }

  void _setIndex(int i) {
    if (i == _index || !mounted) return;
    setState(() {
      _dir = _dirTo(i);
      _index = i;
    });
  }

  void _openList(bool show) {
    if (_showList == show) return;
    setState(() => _showList = show);
    // Focus can only move once the other layer is no longer excluded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (show ? _tileFocus[_index] : _playFocus).requestFocus();
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -300) _step(1);
    if (v > 300) _step(-1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.mediaPlayPause) {
      _toggle();
    } else if (k == LogicalKeyboardKey.mediaTrackNext) {
      _step(1);
    } else if (k == LogicalKeyboardKey.mediaTrackPrevious) {
      _step(-1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _transition(Widget child, Animation<double> anim) {
    final incoming = child.key == ValueKey<int>(_index);
    final begin = Offset((incoming ? _dir : -_dir) * 0.4, 0);
    return SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(anim),
      child: FadeTransition(opacity: anim, child: child),
    );
  }

  /// Square album-art style card, centred in the space it is given
  /// (left half in landscape / TV, top area in portrait).
  Widget _buildArt(Station st, {double fraction = 0.86}) {
    return LayoutBuilder(builder: (context, c) {
      final side = math.min(c.maxWidth, c.maxHeight) * fraction;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _onSwipe,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: _transition,
            child: StationCard(key: ValueKey<int>(_index), station: st, size: side),
          ),
        ),
      );
    });
  }

  /// Dots, volume and transport buttons, centred in the right half.
  Widget _buildControls() {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StationDots(count: stations.length, index: _index),
              const SizedBox(height: 24),
              VolumeBar(
                volume: _volume,
                onChanged: (v) {
                  _volume.value = v;
                  VolumeController.instance.setVolume(v);
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 42,
                    style: remoteFocusStyle,
                    tooltip: 'Previous',
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: () => _step(-1),
                  ),
                  const SizedBox(width: 16),
                  PlayButton(
                    player: _player,
                    focusNode: _playFocus,
                    onTap: _toggle,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 42,
                    style: remoteFocusStyle,
                    tooltip: 'Next',
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: () => _step(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = stations[_index];

    return PopScope(
      canPop: _showList,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openList(true);
      },
      // Only receives key events bubbling up from the buttons. It must never
      // take focus itself, or the remote could land on this invisible
      // full-screen node and the highlight would seem to vanish.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: Stack(
            children: [
              GradientBackdrop(color: st.color),
              ExcludeFocus(
                excluding: _showList,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            const SizedBox(width: 48),
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'LIVE RADIO',
                                  style: TextStyle(
                                    letterSpacing: 3,
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Stations',
                              style: remoteFocusStyle,
                              icon: const Icon(Icons.queue_music_rounded),
                              onPressed: () => _openList(true),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) => box.maxWidth > box.maxHeight
                              // Landscape / Android TV: art left, controls right.
                              ? Row(
                                  children: [
                                    Expanded(child: _buildArt(st)),
                                    Expanded(child: _buildControls()),
                                  ],
                                )
                              // Portrait phone: art on top, controls below.
                              : Column(
                                  children: [
                                    Expanded(
                                        child: _buildArt(st, fraction: 0.78)),
                                    const SizedBox(height: 16),
                                    _buildControls(),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: ExcludeFocus(
                  excluding: !_showList,
                  child: IgnorePointer(
                    ignoring: !_showList,
                    child: AnimatedSlide(
                      offset: _showList ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      child: StationList(
                        selected: _index,
                        focusNodes: _tileFocus,
                        onSelect: (i) => _select(i, closeList: true),
                        onBack: () => _openList(false),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
