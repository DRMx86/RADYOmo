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
  // Initialize player with a browser User-Agent to prevent server blocks
  final AudioPlayer _player = AudioPlayer(
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  );

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Catch the real ExoPlayer error if it happens
    _player.errorStream.listen((error) {
      setState(() {
        _errorMessage = "Playback Error: ${error.toString()}";
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playRadio(String url, String title, String frequency) async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      // IMPORTANT: You MUST wrap the URI in a MediaItem for background audio
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: title, 
            title: title,
            artist: frequency,
            artUri: Uri.parse('https://via.placeholder.com/300'), // Replace with your logo
          ),
        ),
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _player.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE RADIO', style: TextStyle(letterSpacing: 2)),
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
            child: Center(
              child: Container(
                width: 300,
                height: 350,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53E3E), // Red color from your screenshot
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53E3E).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.radio, size: 60, color: Colors.white70),
                    const SizedBox(height: 20),
                    const Text(
                      'Monster\nRadio',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    const SizedBox(height: 10),
                    const Text('RX 93.1', style: TextStyle(fontSize: 18, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          
          // Play Button
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: GestureDetector(
              onTap: () {
                if (_player.playing) {
                  _player.pause();
                } else {
                  // Replace with your ACTUAL URL
                  _playRadio('https://in-icecast.eradioportal.com:8443/monsterrrx', 'Monster Radio', 'RX 93.1');
                }
                setState(() {});
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF34D399), // Green button
                ),
                child: _isLoading 
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : Icon(
                      _player.playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 40,
                    ),
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
