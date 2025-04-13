import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final List<String> videoAssets = [
    'assets/add-device.mp4',
    'assets/adduser.mp4',
    'assets/demo.mp4',
  ];

  final List<String> videoTitles = [
    'How to Add a Device',
    'How to Add a User',
    'Emergency Response Demo',
  ];

  final List<TextSpan> videoSubtitles = [
    TextSpan(
      text: 'Users can register their IoT device to the app to start monitoring sensor data and receive real-time alerts.',
    ),
    TextSpan(
      text: 'Owners of the IoT device can easily add fellow household members to share access and monitor the device together.',
    ),
    TextSpan(
      children: [
        const TextSpan(text: 'This demo takes you through the entire process: starting with a '),
        TextSpan(
          text: 'smart notification',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const TextSpan(text: ' that warns you of rising air quality, followed by an '),
        TextSpan(
          text: 'alarm trigger',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const TextSpan(text: ' once thresholds are exceeded. You\'ll also see how to '),
        TextSpan(
          text: 'call the fire station',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const TextSpan(text: ' and check your '),
        TextSpan(
          text: 'alarm history',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const TextSpan(text: ' for a complete safety response.'),
      ],
    ),
  ];

  int _currentIndex = 0;
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _videoPlayerController = VideoPlayerController.asset(videoAssets[_currentIndex])
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
        }
      });

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: 16 / 9,
      placeholder: _isVideoInitialized ? null : Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      ),
      autoInitialize: true,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFFFFDE59),
        handleColor: const Color(0xFFFFDE59),
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.withOpacity(0.5),
      ),
    );
  }

  Future<void> _changeVideo(int newIndex) async {
    if (newIndex >= 0 && newIndex < videoAssets.length) {
      await _videoPlayerController.dispose();
      _chewieController.dispose();

      if (mounted) {
        setState(() {
          _currentIndex = newIndex;
          _isVideoInitialized = false;
          _initializeVideoPlayer();
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Tutorials'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFFFDE59),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              children: [
                Text(
                  videoTitles[_currentIndex],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                    children: [videoSubtitles[_currentIndex]],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Chewie(controller: _chewieController),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentIndex > 0 ? () => _changeVideo(_currentIndex - 1) : null,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: _currentIndex > 0 ? const Color(0xFFFFDE59) : Colors.grey[400],
                  ),
                  child: Icon(Icons.arrow_back, size: 28, color: _currentIndex > 0 ? Colors.black : Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDE59).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} of ${videoAssets.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _currentIndex < videoAssets.length - 1 ? () => _changeVideo(_currentIndex + 1) : null,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: _currentIndex < videoAssets.length - 1 ? const Color(0xFFFFDE59) : Colors.grey[400],
                  ),
                  child: Icon(Icons.arrow_forward, size: 28, color: _currentIndex < videoAssets.length - 1 ? Colors.black : Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}