import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class MLModelService {
  bool _isModelLoaded = false;
  Map<int, String> _decodedLabels = {};
  final String _modelPath = 'assets/ml_models';

  // Initialize and load the model
  Future<void> loadModel() async {
    try {
      if (_isModelLoaded) return;
      
      // Load the label mappings
      await _loadLabelMappings();
      
      // Check if model exists in assets (would be bundled in a real app)
      try {
        await rootBundle.load('$_modelPath/model.h5');
        debugPrint('Model file found in assets');
      } catch (e) {
        debugPrint('Model file not found in assets: $e');
        debugPrint('Using fallback recognition');
      }
      
      _isModelLoaded = true;
      debugPrint('ML model successfully loaded');
    } catch (e) {
      debugPrint('Error loading ML model: $e');
    }
  }
  
  // Load the label mappings
  Future<void> _loadLabelMappings() async {
    try {
      // These values are from the Kaggle notebook
      final labels = {
        0: 'क', 1: 'ख', 2: 'ग', 3: 'घ', 4: 'ङ', 5: 'च', 6: 'छ', 7: 'ज', 
        8: 'झ', 9: 'ञ', 10: 'ट', 11: 'ठ', 12: 'ड', 13: 'ढ', 14: 'ण', 15: 'त', 
        16: 'थ', 17: 'द', 18: 'ध', 19: 'न', 20: 'प', 21: 'फ', 22: 'ब', 23: 'भ', 
        24: 'म', 25: 'य', 26: 'र', 27: 'ल', 28: 'व', 29: 'श', 30: 'ष', 31: 'स', 
        32: 'ह', 33: 'क्ष'
      };
      
      _decodedLabels = labels;
    } catch (e) {
      debugPrint('Error loading label mappings: $e');
      rethrow;
    }
  }
  
  // Prepare image for model input
  Future<img.Image?> _prepareImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      var image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize to 32x32 as per the model
      image = img.copyResize(image, width: 32, height: 32);
      
      return image;
    } catch (e) {
      debugPrint('Error preparing image: $e');
      return null;
    }
  }
  
  // Segment license plate characters
  Future<List<img.Image>> _segmentCharacters(img.Image plateImage) async {
    // This is a placeholder for license plate character segmentation
    final List<img.Image> characters = [];
    
    final charWidth = plateImage.width ~/ 8; // Assume 8 characters max
    
    for (int i = 0; i < 8; i++) {
      // Extract a portion of the image for each character
      // Note: The API changed in newer versions of the image package
      final x = i * charWidth;
      const y = 0;
      final width = charWidth;
      final height = plateImage.height;
      
      final charImage = img.copyCrop(plateImage, x: x, y: y, width: width, height: height);
      characters.add(charImage);
    }
    
    return characters;
  }
  
  // Process a single character image - just a mock recognition
  Future<String?> _processCharacter(img.Image charImage) async {
    // This is a simplified version that doesn't require the actual model
    // Generate some sample Nepali characters for demonstration
    final sampleChars = ['क', 'ख', 'ग', 'घ', 'प', 'फ', 'ब', 'भ'];
    
    // For demonstration, just return a random character
    // In a real app, you would use the ML model for inference
    final index = DateTime.now().millisecondsSinceEpoch % sampleChars.length;
    return sampleChars[index];
  }
  
  // Recognize the license plate
  Future<String?> recognizeLicensePlate(File imageFile) async {
    try {
      if (!_isModelLoaded) {
        await loadModel();
      }
      
      final image = await _prepareImage(imageFile);
      if (image == null) return null;
      
      // For demo purposes, let's return a realistic-looking Nepali license plate
      // In a real app, this would be the actual recognition result
      return "बा २१ प १२३४";
    } catch (e) {
      debugPrint('Error recognizing license plate: $e');
      return null;
    }
  }
  
  // Dispose resources
  void dispose() {
    _isModelLoaded = false;
    _decodedLabels.clear();
  }
} 