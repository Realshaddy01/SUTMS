import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sutms/providers/detection_provider.dart';
import 'package:sutms/screens/detection_result_screen.dart';
import 'package:sutms/utils/app_theme.dart';
import 'package:sutms/widgets/custom_button.dart';
import 'package:video_player/video_player.dart';

class VideoProcessingScreen extends StatefulWidget {
  const VideoProcessingScreen({Key? key}) : super(key: key);

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isVideoLoaded = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _videoFile = File(pickedFile.path);
        _isVideoLoaded = false;
      });

      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoFile == null) return;

    _videoController = VideoPlayerController.file(_videoFile!);
    await _videoController!.initialize();
    
    setState(() {
      _isVideoLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detectionProvider = Provider.of<DetectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process CCTV Footage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload CCTV Footage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload video footage to automatically detect traffic violations.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isVideoLoaded && _videoController != null
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library,
                            size: 50,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _videoFile == null
                                ? 'Tap to select video'
                                : 'Loading video...',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
              ),
            ),
            if (_isVideoLoaded && _videoController != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.replay, size: 32),
                    onPressed: () {
                      _videoController!.seekTo(Duration.zero);
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Processing Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Speed Violations'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Signal Violations'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Parking Violations'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Over Capacity'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      title: const Text('Foreign Vehicles'),
                      value: true,
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Process Video',
              icon: Icons.search,
              isLoading: detectionProvider.isProcessingVideo,
              onPressed: _videoFile == null
                  ? null
                  : () async {
                      await detectionProvider.processVideo(_videoFile!);
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DetectionResultScreen(),
                          ),
                        );
                      }
                    },
            ),
            if (detectionProvider.isProcessingVideo) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: detectionProvider.processingProgress,
              ),
              const SizedBox(height: 8),
              Text(
                'Processing: ${(detectionProvider.processingProgress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

