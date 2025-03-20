import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class NumberPlateDetector {
  static const String MODEL_FILE = "assets/models/number_plate_detector.tflite";
  static const String LABELS_FILE = "assets/models/number_plate_labels.txt";

  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> loadModel() async {
    try {
      final interpreterOptions = InterpreterOptions();
      
      // Load model from assets
      final modelData = await rootBundle.load(MODEL_FILE);
      final modelBuffer = modelData.buffer;
      final modelByteData = modelBuffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes);
      
      // Create temporary file for the model
      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/number_plate_detector.tflite');
      await modelFile.writeAsBytes(modelByteData);
      
      // Load interpreter
      _interpreter = await Interpreter.fromFile(modelFile);
      
      // Load labels
      final labelsData = await rootBundle.loadString(LABELS_FILE);
      _labels = labelsData.split('\n');
      
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future<Map<String, dynamic>?> detectNumberPlate(File imageFile) async {
    if (_interpreter == null) {
      print('Interpreter not initialized');
      return null;
    }
    
    try {
      // Read image
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('Failed to decode image');
        return null;
      }
      
      // Resize image to model input size
      final resizedImage = img.copyResize(image, width: 300, height: 300);
      
      // Convert image to input tensor
      final inputTensor = _imageToTensor(resizedImage);
      
      // Prepare output tensors
      final outputBoxes = List<List<List<double>>>.filled(
        1, List<List<double>>.filled(10, List<double>.filled(4, 0)));
      final outputClasses = List<List<double>>.filled(
        1, List<double>.filled(10, 0));
      final outputScores = List<List<double>>.filled(
        1, List<double>.filled(10, 0));
      final outputCount = List<double>.filled(1, 0);
      
      // Run inference
      final outputs = {
        0: outputBoxes,
        1: outputClasses,
        2: outputScores,
        3: outputCount
      };
      
      _interpreter!.runForMultipleInputs([inputTensor], outputs);
      
      // Process results
      final boxes = outputBoxes[0];
      final classes = outputClasses[0];
      final scores = outputScores[0];
      final count = outputCount[0].toInt();
      
      // Find best detection
      double bestScore = 0;
      int bestIndex = -1;
      
      for (int i = 0; i < count; i++) {
        if (scores[i] > bestScore) {
          bestScore = scores[i];
          bestIndex = i;
        }
      }
      
      if (bestIndex == -1 || bestScore < 0.5) {
        return null;
      }
      
      // Get detection details
      final box = boxes[bestIndex];
      final classId = classes[bestIndex].toInt();
      final className = _labels != null && classId < _labels!.length 
          ? _labels![classId] 
          : 'Unknown';
      
      // Convert normalized coordinates to pixel coordinates
      final ymin = (box[0] * image.height).toInt();
      final xmin = (box[1] * image.width).toInt();
      final ymax = (box[2] * image.height).toInt();
      final xmax = (box[3] * image.width).toInt();
      
      // Extract number plate region
      final plateImage = img.copyCrop(
        image, 
        x: xmin, 
        y: ymin, 
        width: xmax - xmin, 
        height: ymax - ymin
      );
      
      // Save plate image to file
      final tempDir = await getTemporaryDirectory();
      final plateFile = File('${tempDir.path}/plate_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await plateFile.writeAsBytes(img.encodeJpg(plateImage));
      
      // For demo purposes, generate a random license plate
      final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
      final numbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      
      final letter1 = letters[DateTime.now().millisecondsSinceEpoch % letters.length];
      final letter2 = letters[(DateTime.now().millisecondsSinceEpoch + 1) % letters.length];
      final number1 = numbers[DateTime.now().millisecondsSinceEpoch % numbers.length];
      final number2 = numbers[(DateTime.now().millisecondsSinceEpoch + 1) % numbers.length];
      final letter3 = letters[(DateTime.now().millisecondsSinceEpoch + 2) % letters.length];
      final letter4 = letters[(DateTime.now().millisecondsSinceEpoch + 3) % letters.length];
      final number3 = numbers[(DateTime.now().millisecondsSinceEpoch + 2) % numbers.length];
      final number4 = numbers[(DateTime.now().millisecondsSinceEpoch + 3) % numbers.length];
      
      final numberPlate = '$letter1$letter2$number1$number2$letter3$letter4$number3$number4';
      
      // Return detection result
      return {
        'box': [xmin, ymin, xmax, ymax],
        'confidence': bestScore,
        'class': className,
        'plateImage': plateFile,
        'numberPlate': numberPlate,
      };
    } catch (e) {
      print('Error detecting number plate: $e');
      return null;
    }
  }

  List<List<List<double>>> _imageToTensor(img.Image image) {
    // Convert image to RGB
    final rgbImage = img.copyResize(image, width: 300, height: 300);
    
    // Create input tensor
    final tensor = List<List<List<double>>>.filled(
      300, 
      List<List<double>>.filled(
        300, 
        List<double>.filled(3, 0)
      )
    );
    
    // Fill tensor with normalized pixel values
    for (int y = 0; y < rgbImage.height; y++) {
      for (int x = 0; x < rgbImage.width; x++) {
        final pixel = rgbImage.getPixel(x, y);
        tensor[y][x][0] = img.getRed(pixel) / 255.0;
        tensor[y][x][1] = img.getGreen(pixel) / 255.0;
        tensor[y][x][2] = img.getBlue(pixel) / 255.0;
      }
    }
    
    return tensor;
  }

  void dispose() {
    _interpreter?.close();
  }
}

