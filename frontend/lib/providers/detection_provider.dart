import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sutms/utils/api_constants.dart';
import 'package:sutms/models/detection_result.dart';
import 'package:sutms/services/api_service.dart';
import 'package:sutms/algorithms/number_plate_detector.dart';
import 'package:sutms/algorithms/violation_detector.dart';

enum DetectionType {
  numberPlate,
  speedViolation,
  signalViolation,
  parkingViolation,
  overCapacity,
  foreignVehicle
}

class DetectionProvider with ChangeNotifier {
  final NumberPlateDetector _numberPlateDetector = NumberPlateDetector();
  final ViolationDetector _violationDetector = ViolationDetector();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isModelLoaded = false;
  String? _error;
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
      await _numberPlateDetector.loadModel();
      
      // Load violation detection model
      await _violationDetector.loadModel();

      _isModelLoaded = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load models: $e';
      _isLoading = false;
      notifyListeners();
    }
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
      final detection = await _numberPlateDetector.detectNumberPlate(imageFile);
      
      if (detection != null) {
        // Add to detection results
        _detectionResults.add(
          DetectionResult(
            id: DateTime.now().millisecondsSinceEpoch,
            numberPlate: detection['numberPlate'] ?? 'ABC123', // Use detected plate or fallback
            detectionType: DetectionType.numberPlate,
            confidence: detection['confidence'],
            timestamp: DateTime.now(),
            imageFile: detection['plateImage'] ?? imageFile,
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
      
      // Process video for violations
      final results = await _violationDetector.processVideo(
        videoFile,
        (progress) {
          _processingProgress = progress;
          notifyListeners();
        },
      );
      
      _detectionResults.clear();
      _detectionResults.addAll(results);

      _isProcessingVideo = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error processing video: $e';
      _isProcessingVideo = false;
      notifyListeners();
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

      final success = await _apiService.reportDetectionViolation(
        token,
        detection.id.toString(),
        location,
        detection.imageFile,
        detection.numberPlate,
        _getViolationTypeString(detection.detectionType),
      );

      _isLoading = false;
      notifyListeners();
      return success;
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
    _numberPlateDetector.dispose();
    _violationDetector.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }
}

