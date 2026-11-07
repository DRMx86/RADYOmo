import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'stations.dart';

const _green = Color(0xFF1DB954);
const _bg = Color(0xFF121212);

/// Full-screen tinted gradient that follows the current station colour.
class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(153), _bg],
            stops: const [0, 0.7],
          ),
        ),
      );
}

/// Square, rounded "album art" card. Everything scales with [size].
class StationCard extends StatelessWidget {
  const StationCard({super.key, required this.station, required this.size});
  final Station station;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.09),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [station.color, station.soft],
          ),
          boxShadow: [
            BoxShadow(
              color: station.color.withAlpha(115),
              blurRadius: size * 0.1,
              offset: Offset(0, size * 0.05),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radio, size: size * 0.2, color: Colors.white70),
              SizedBox(height: size * 0.06),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  station.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size * 0.11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: size * 0.02),
              Text(
                station.freq,
                style: TextStyle(
                  fontSize: size * 0.065,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StationDots extends StatelessWidget {
  const StationDots({super.key, required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? Colors.white : Colors.white30,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}

/// Volume slider; only this widget rebuilds when the volume changes.
class VolumeBar extends StatelessWidget {
  const VolumeBar({super.key, required this.volume, required this.onChanged});
  final ValueNotifier<double> volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              child: ValueListenableBuilder<double>(
                valueListenable: volume,
                builder: (_, v, __) =>
                    Slider(value: v.clamp(0.0, 1.0).toDouble(), onChanged: onChanged),
              ),
            ),
          ),
          const Icon(Icons.volume_up, color: Colors.white54, size: 20),
        ],
      ),
    );
  }
}

/// Round play/pause button with a TV focus ring. Only it listens to the
/// player state stream.
class PlayButton extends StatefulWidget {
  const PlayButton({
    super.key,
    required this.player,
    required this.focusNode,
    required this.onTap,
  });
  final AudioPlayer player;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: widget.player.playerStateStream,
      builder: (context, snap) {
        final s = snap.data;
        final busy = s?.processingState == ProcessingState.loading ||
            s?.processingState == ProcessingState.buffering;
        final playing = s?.playing ?? false;
        return Material(
          color: _green,
          shape: CircleBorder(
            side: _focused
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            focusNode: widget.focusNode,
            onFocusChange: (f) => setState(() => _focused = f),
            onTap: widget.onTap,
            child: SizedBox.square(
              dimension: 78,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.black),
                    )
                  : Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 46,
                      color: Colors.black,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen "Select Station" layer.
class StationList extends StatelessWidget {
  const StationList({
    super.key,
    required this.selected,
    required this.focusNodes,
    required this.onSelect,
    required this.onBack,
  });
  final int selected;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  const Text('Select Station',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Choose a radio station to start listening',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.separated(
                      itemCount: stations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => _StationTile(
                        station: stations[i],
                        selected: i == selected,
                        focusNode: focusNodes[i],
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: onBack,
                      child: const Text('Back to player'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StationTile extends StatefulWidget {
  const _StationTile({
    required this.station,
    required this.selected,
    required this.onTap,
    required this.focusNode,
  });
  final Station station;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_StationTile> createState() => _StationTileState();
}

class _StationTileState extends State<_StationTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onTap: widget.onTap,
        child: Ink(
          height: 104,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [s.color, s.color.withAlpha(128)],
            ),
            border: _focused
                ? Border.all(color: Colors.white, width: 4)
                : widget.selected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(s.freq,
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
