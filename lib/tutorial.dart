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
    'assets/adduser.mp4',
    'assets/add-device.mp4',
  ];
  final List<String> videoTitles = [
    'How to Add a User',
    'How to Add a Device',
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
        setState(() {
          _isVideoInitialized = true;
        });

        // Add listener for video completion
        _videoPlayerController.addListener(_videoListener);
      });

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: 16 / 9,
      placeholder: _isVideoInitialized
          ? null
          : Container(
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
      // Show controls when video ends
      showControls: true,
      // Customize the controls
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.withOpacity(0.5),
      ),
    );
  }

  void _videoListener() {
    if (_videoPlayerController.value.isInitialized &&
        !_videoPlayerController.value.isBuffering &&
        !_videoPlayerController.value.isPlaying &&
        _videoPlayerController.value.position == _videoPlayerController.value.duration) {
      // Video ended - force show controls by rebuilding
      setState(() {});
    }
  }

  void _changeVideo(int newIndex) {
    if (newIndex >= 0 && newIndex < videoAssets.length) {
      // Remove old listener
      _videoPlayerController.removeListener(_videoListener);

      setState(() {
        _currentIndex = newIndex;
        _isVideoInitialized = false;
        _videoPlayerController.dispose();
        _chewieController.dispose();
        _initializeVideoPlayer();
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_videoListener);
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
      ),
      body: Column(
        children: [
          // Video Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              videoTitles[_currentIndex],
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Video Player
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Chewie(controller: _chewieController),
              ),
            ),
          ),

          // Navigation Controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                ElevatedButton(
                  onPressed: _currentIndex > 0 ? () => _changeVideo(_currentIndex - 1) : null,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16.0),
                  ),
                  child: const Icon(Icons.arrow_back, size: 28),
                ),

                // Progress Indicator
                Text(
                  '${_currentIndex + 1} of ${videoAssets.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),

                // Next Button
                ElevatedButton(
                  onPressed: _currentIndex < videoAssets.length - 1 ? () => _changeVideo(_currentIndex + 1) : null,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16.0),
                  ),
                  child: const Icon(Icons.arrow_forward, size: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}