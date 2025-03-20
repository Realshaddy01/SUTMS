import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sutms/providers/auth_provider.dart';
import 'package:sutms/providers/detection_provider.dart';
import 'package:sutms/models/detection_result.dart';
import 'package:sutms/theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class DetectionResultScreen extends StatefulWidget {
  const DetectionResultScreen({Key? key}) : super(key: key);

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  String _currentLocation = 'Fetching location...';
  bool _isFetchingLocation = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          _currentLocation = '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = 'Unable to fetch location';
          _isFetchingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detectionProvider = Provider.of<DetectionProvider>(context);
    final results = detectionProvider.detectionResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              detectionProvider.clearDetectionResults();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: results.isEmpty
          ? const Center(
              child: Text('No violations detected'),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detection Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Total detections: ${results.length}'),
                          const SizedBox(height: 4),
                          Text(
                            'Location: $_currentLocation',
                            style: TextStyle(
                              color: _isFetchingLocation ? Colors.grey : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Time: ${DateTime.now().toString().substring(0, 19)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return _buildDetectionCard(context, result);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDetectionCard(BuildContext context, DetectionResult result) {
    final authProvider = Provider.of<AuthProvider>(context);
    final detectionProvider = Provider.of<DetectionProvider>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.imageFile != null)
            SizedBox(
              width: double.infinity,
              height: 200,
              child: Image.file(
                result.imageFile!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 50),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      result.numberPlate,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getViolationColor(result.detectionType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getViolationColor(result.detectionType),
                        ),
                      ),
                      child: Text(
                        result.violationTypeString,
                        style: TextStyle(
                          color: _getViolationColor(result.detectionType),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%'),
                const SizedBox(height: 4),
                Text('Time: ${result.formattedTimestamp}'),
                if (result.videoTimestamp != null) ...[
                  const SizedBox(height: 4),
                  Text('Video Timestamp: ${result.formattedVideoTimestamp}'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: detectionProvider.isLoading
                            ? null
                            : () async {
                                final success = await detectionProvider.reportViolation(
                                  authProvider.token!,
                                  result,
                                  _currentLocation,
                                );
                                
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Violation reported successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: const Icon(Icons.report),
                        label: const Text('Report Violation'),
                      ),
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

  Color _getViolationColor(DetectionType type) {
    switch (type) {
      case DetectionType.numberPlate:
        return Colors.blue;
      case DetectionType.speedViolation:
        return Colors.red;
      case DetectionType.signalViolation:
        return Colors.orange;
      case DetectionType.parkingViolation:
        return Colors.purple;
      case DetectionType.overCapacity:
        return Colors.brown;
      case DetectionType.foreignVehicle:
        return Colors.teal;
    }
  }
}

