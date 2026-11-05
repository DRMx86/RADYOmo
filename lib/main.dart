import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.radyomo.channel.audio',
    androidNotificationChannelName: 'RADYOmo Playback',
    androidNotificationOngoing: true,
  );

  runApp(const RadioApp());
}

// Data model for the stations
class RadioStation {
  final String name;
  final String frequency;
  final String url;
  final Color color;
  final String logoUrl;

  RadioStation({
    required this.name,
    required this.frequency,
    required this.url,
    required this.color,
    required this.logoUrl,
  });
}

class RadioApp extends StatelessWidget {
  const RadioApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RADYOmo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF161616),
      ),
      home: const RadioPlayerScreen(),
    );
  }
}

class RadioPlayerScreen extends StatefulWidget {
  const RadioPlayerScreen({Key? key}) : super(key: key);

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer(
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  );

  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentIndex = 0;
  String? _errorMessage;
  bool _isLoading = false;
  int? _playingStationIndex; // Tracks which station is currently loaded

  // List of stations. Update the URLs and logos as needed!
  final List<RadioStation> stations = [
    RadioStation(
      name: 'Magic',
      frequency: '89.9',
      url: 'https://in-icecast.eradioportal.com:8443/magic899', // Replace if needed
      color: const Color(0xFFE67E22), // Orange
      logoUrl: 'https://via.placeholder.com/300/E67E22/FFFFFF?text=Magic+89.9',
    ),
    RadioStation(
      name: 'Monster\nRadio',
      frequency: 'RX 93.1',
      url: 'https://in-icecast.eradioportal.com:8443/monsterrrx',
      color: const Color(0xFFE53E3E), // Red
      logoUrl: 'https://via.placeholder.com/300/E53E3E/FFFFFF?text=Monster+Radio',
    ),
    RadioStation(
      name: 'Barangay\nLS',
      frequency: '97.1',
      url: 'https://in-icecast.eradioportal.com:8443/barangayls', // Replace if needed
      color: const Color(0xFF2980B9), // Blue
      logoUrl: 'https://via.placeholder.com/300/2980B9/FFFFFF?text=Barangay+LS',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _player.playbackEventStream.listen(
      (event) {},
      onError: (Object error, StackTrace stackTrace) {
        setState(() {
          _errorMessage = "Playback Error: ${error.toString()}";
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(int index) async {
    final station = stations[index];

    // If clicking play on a station that isn't currently loaded
    if (_playingStationIndex != index) {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
        _playingStationIndex = index;
      });

      try {
        await _player.stop(); // Stop whatever is currently playing
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(station.url),
            tag: MediaItem(
              id: station.name,
              title: station.name.replaceAll('\n', ' '),
              artist: station.frequency,
              artUri: Uri.parse(station.logoUrl),
            ),
          ),
        );
        
        if (mounted) setState(() => _isLoading = false);
        _player.play();
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = "Error: $e";
            _isLoading = false;
          });
        }
      }
    } else {
      // If clicking play/pause on the station that is already loaded
      if (_player.playing) {
        _player.pause();
      } else {
        _player.play();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE RADIO', style: TextStyle(letterSpacing: 2, fontSize: 14)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: stations.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final station = stations[index];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
                  decoration: BoxDecoration(
                    color: station.color,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      if (_currentIndex == index)
                        BoxShadow(
                          color: station.color.withOpacity(0.4),
                          blurRadius: 50,
                          spreadRadius: 10,
                        )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.radio, size: 70, color: Colors.white70),
                      const SizedBox(height: 30),
                      Text(
                        station.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36, 
                          fontWeight: FontWeight.bold, 
                          height: 1.1,
                          color: Colors.white
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        station.frequency, 
                        style: const TextStyle(fontSize: 20, color: Colors.white70)
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Page Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              stations.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentIndex == index ? 24 : 6,
                decoration: BoxDecoration(
                  color: _currentIndex == index ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Play Button
          GestureDetector(
            onTap: () => _togglePlay(_currentIndex),
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 40),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF34D399), // Green button
              ),
              child: _isLoading && _playingStationIndex == _currentIndex
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: Colors.black),
                  )
                : Icon(
                    (_player.playing && _playingStationIndex == _currentIndex) 
                        ? Icons.pause 
                        : Icons.play_arrow,
                    color: Colors.black,
                    size: 40,
                  ),
            ),
          ),

          // Error Message Display
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}
