import 'dart:io';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';

class PlateResultCard extends StatelessWidget {
  final String plateText;
  final double confidence;
  final Vehicle? vehicle;
  final String? imagePath;
  final VoidCallback onCreateViolation;
  
  const PlateResultCard({
    Key? key,
    required this.plateText,
    required this.confidence,
    this.vehicle,
    this.imagePath,
    required this.onCreateViolation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: Constants.cardElevation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imagePath != null && imagePath!.isNotEmpty)
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4.0)),
                child: Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(Constants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        plateText != 'No plate detected' ? Icons.check_circle : Icons.cancel,
                        color: plateText != 'No plate detected' ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: Constants.smallPadding),
                      Expanded(
                        child: Text(
                          plateText,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Constants.smallPadding / 2),
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (vehicle != null) ...[
                    const Divider(),
                    Text(
                      'Vehicle Details:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Constants.smallPadding / 2),
                    _buildVehicleInfo('Type', vehicle!.type),
                    _buildVehicleInfo('Make', vehicle!.make),
                    _buildVehicleInfo('Model', vehicle!.model),
                    _buildVehicleInfo('Color', vehicle!.color),
                  ] else if (plateText != 'No plate detected') ...[
                    const Divider(),
                    Text(
                      'Vehicle not registered in system',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_late),
                    label: const Text('Create Violation'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                    ),
                    onPressed: plateText != 'No plate detected' ? onCreateViolation : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVehicleInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
