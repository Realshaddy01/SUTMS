import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:sutms/main.dart';
import 'package:sutms/providers/detection_provider.dart';
import 'package:sutms/screens/detection_result_screen.dart';
import 'package:sutms/utils/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isProcessingImage = false;
  int _selectedCameraIndex = 0;
  File? _videoFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      setState(() {
        _isInitialized = false;
      });
      return;
    }

    final cameraController = CameraController(
      cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    _controller = cameraController;

    try {
      await cameraController.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length <= 1) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_isInitialized || _isProcessingImage) return;

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);

      // Process the image for number plate detection
      final detectionProvider = Provider.of<DetectionProvider>(context, listen: false);
      await detectionProvider.processImage(imageFile);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DetectionResultScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_isInitialized || _isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      debugPrint('Error starting video recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting video recording: $e')),
      );
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isInitialized || !_isRecording) return;

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoFile = File(videoFile.path);
      });

      if (_videoFile != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPreviewScreen(videoFile: _videoFile!),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping video recording: $e')),
      );
      setState(() {
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          
          // Top controls
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (cameras.length > 1)
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: _switchCamera,
                  ),
              ],
            ),
          ),
          
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Photo mode button
                IconButton(
                  icon: Icon(
                    Icons.photo_camera,
                    color: !_isRecording ? Colors.white : Colors.grey,
                    size: 36,
                  ),
                  onPressed: _isRecording ? null : _takePicture,
                ),
                
                // Record button
                GestureDetector(
                  onTap: _isRecording ? _stopVideoRecording : _startVideoRecording,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: _isRecording ? Colors.red : Colors.transparent,
                    ),
                    child: _isRecording
                        ? const Icon(Icons.stop, color: Colors.white, size: 30)
                        : const SizedBox(width: 10, height: 10),
                  ),
                ),
                
                // Video mode button
                IconButton(
                  icon: Icon(
                    Icons.videocam,
                    color: _isRecording ? Colors.red : Colors.white,
                    size: 36,
                  ),
                  onPressed: _isProcessingImage ? null : () {}, // Just a mode indicator
                ),
              ],
            ),
          ),
          
          // Processing indicator
          if (_isProcessingImage)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  final File videoFile;

  const VideoPreviewScreen({Key? key, required this.videoFile}) : super(key: key);

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final detectionProvider = Provider.of<DetectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Preview'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'Video Preview',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: detectionProvider.isProcessingVideo
                      ? null
                      : () async {
                          await detectionProvider.processVideo(widget.videoFile);
                          if (mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const DetectionResultScreen(),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.search),
                  label: const Text('Process for Violations'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 16),
                if (detectionProvider.isProcessingVideo)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: detectionProvider.processingProgress,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Processing: ${(detectionProvider.processingProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

