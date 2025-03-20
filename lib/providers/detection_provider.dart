import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sutms/utils/api_constants.dart';
import 'package:sutms/models/detection_result.dart';

enum DetectionType {
  numberPlate,
  speedViolation,
  signalViolation,
  parkingViolation,
  overCapacity,
  foreignVehicle
}

class DetectionProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isModelLoaded = false;
  String? _error;
  Interpreter? _numberPlateDetector;
  Interpreter? _violationDetector;
  List<DetectionResult> _detectionResults = [];
  VideoPlayerController? _videoPlayerController;
  bool _isProcessingVideo = false;
  double _processingProgress = 0.0;

  bool get isLoading => _isLoading;
  bool get isModelLoaded => _isModelLoaded;
  String? get error => _error;
  List<DetectionResult> get detectionResults => _detectionResults;
  VideoPlayerController? get videoPlayerController => _videoPlayerController;
  bool get isProcessingVideo => _isProcessingVideo;
  double get processingProgress => _processingProgress;

  DetectionProvider() {
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Load number plate detection model
      final numberPlateModelFile = await _getModel('assets/models/number_plate_detector.tflite');
      _numberPlateDetector = await Interpreter.fromFile(numberPlateModelFile);

      // Load violation detection model
      final violationModelFile = await _getModel('assets/models/violation_detector.tflite');
      _violationDetector = await Interpreter.fromFile(violationModelFile);

      _isModelLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load models: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<File> _getModel(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final file = File('${(await getTemporaryDirectory()).path}/${assetPath.split('/').last}');
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file;
  }

  Future<void> processImage(File imageFile) async {
    if (!_isModelLoaded) {
      _error = 'Models not loaded yet';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Process image for number plate detection
      final numberPlate = await _detectNumberPlate(imageFile);
      
      if (numberPlate != null) {
        // Add to detection results
        _detectionResults.add(
          DetectionResult(
            id: DateTime.now().millisecondsSinceEpoch,
            numberPlate: numberPlate,
            detectionType: DetectionType.numberPlate,
            confidence: 0.95, // Example confidence score
            timestamp: DateTime.now(),
            imageFile: imageFile,
          ),
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error processing image: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _detectNumberPlate(File imageFile) async {
    // In a real implementation, this would use the TFLite model to detect the number plate
    // For demonstration purposes, we'll return a mock result
    await Future.delayed(const Duration(seconds: 1)); // Simulate processing time
    return 'ABC123'; // Mock number plate
  }

  Future<void> processVideo(File videoFile) async {
    if (!_isModelLoaded) {
      _error = 'Models not loaded yet';
      notifyListeners();
      return;
    }

    try {
      _isProcessingVideo = true;
      _processingProgress = 0.0;
      _error = null;
      notifyListeners();

      // Initialize video player
      _videoPlayerController = VideoPlayerController.file(videoFile);
      await _videoPlayerController!.initialize();
      
      final duration = _videoPlayerController!.value.duration;
      final frameCount = duration.inMilliseconds ~/ 200; // Process a frame every 200ms
      
      _detectionResults.clear();
      
      // Process video frames
      for (int i = 0; i < frameCount; i++) {
        // Seek to specific position
        await _videoPlayerController!.seekTo(Duration(milliseconds: i * 200));
        await Future.delayed(const Duration(milliseconds: 50)); // Wait for seek to complete
        
        // Capture frame
        final frame = await _captureFrame();
        if (frame != null) {
          // Process frame for violations
          await _detectViolationsInFrame(frame, i * 200);
        }
        
        // Update progress
        _processingProgress = (i + 1) / frameCount;
        notifyListeners();
      }

      _isProcessingVideo = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error processing video: $e';
      _isProcessingVideo = false;
      notifyListeners();
    }
  }

  Future<File?> _captureFrame() async {
    try {
      // This is a simplified version. In a real app, you would capture the actual frame
      // from the video player and save it as an image file.
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Mock frame capture
      await file.writeAsBytes(Uint8List(100)); // Placeholder data
      
      return file;
    } catch (e) {
      debugPrint('Error capturing frame: $e');
      return null;
    }
  }

  Future<void> _detectViolationsInFrame(File frameFile, int timestamp) async {
    // In a real implementation, this would use the TFLite model to detect violations
    // For demonstration purposes, we'll add mock violations
    
    // Randomly detect violations (for demo purposes)
    if (timestamp % 1000 == 0) { // Every 5 seconds in the video
      final violationType = DetectionType.values[timestamp % DetectionType.values.length];
      
      _detectionResults.add(
        DetectionResult(
          id: DateTime.now().millisecondsSinceEpoch,
          numberPlate: 'XYZ${timestamp ~/ 1000}',
          detectionType: violationType,
          confidence: 0.85 + (timestamp % 15) / 100, // Random confidence between 0.85 and 0.99
          timestamp: DateTime.now(),
          imageFile: frameFile,
          videoTimestamp: Duration(milliseconds: timestamp),
        ),
      );
    }
  }

  Future<bool> reportViolation(
    String token,
    DetectionResult detection,
    String location,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/violations/report/'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Token $token',
      });

      // Add fields
      request.fields['vehicle_number'] = detection.numberPlate;
      request.fields['violation_type'] = _getViolationTypeString(detection.detectionType);
      request.fields['location'] = location;
      request.fields['confidence'] = detection.confidence.toString();
      
      // Add image file
      if (detection.imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'evidence_image',
            detection.imageFile!.path,
          ),
        );
      }

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to report violation: $responseData';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error reporting violation: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getViolationTypeString(DetectionType type) {
    switch (type) {
      case DetectionType.numberPlate:
        return 'number_plate';
      case DetectionType.speedViolation:
        return 'speeding';
      case DetectionType.signalViolation:
        return 'signal_jump';
      case DetectionType.parkingViolation:
        return 'parking';
      case DetectionType.overCapacity:
        return 'over_capacity';
      case DetectionType.foreignVehicle:
        return 'foreign_vehicle';
    }
  }

  void clearDetectionResults() {
    _detectionResults.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _numberPlateDetector?.close();
    _violationDetector?.close();
    _videoPlayerController?.dispose();
    super.dispose();
  }
}

