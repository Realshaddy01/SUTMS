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
                borderRadius: BorderRadius.vertical(top: Radius.circular(4.0)),
                child: Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.all(Constants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        plateText != 'No plate detected' ? Icons.check_circle : Icons.cancel,
                        color: plateText != 'No plate detected' ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: Constants.smallPadding),
                      Expanded(
                        child: Text(
                          plateText,
                          style: Theme.of(context).textTheme.headline6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Constants.smallPadding / 2),
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyText2,
                  ),
                  if (vehicle != null) ...[
                    Divider(),
                    Text(
                      'Vehicle Details:',
                      style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: Constants.smallPadding / 2),
                    _buildVehicleInfo('Type', vehicle!.vehicleType),
                    if (vehicle!.make != null) _buildVehicleInfo('Make', vehicle!.make!),
                    if (vehicle!.model != null) _buildVehicleInfo('Model', vehicle!.model!),
                    if (vehicle!.color != null) _buildVehicleInfo('Color', vehicle!.color!),
                  ] else if (plateText != 'No plate detected') ...[
                    Divider(),
                    Text(
                      'Vehicle not registered in system',
                      style: Theme.of(context).textTheme.bodyText2,
                    ),
                  ],
                  Spacer(),
                  ElevatedButton.icon(
                    icon: Icon(Icons.assignment_late),
                    label: Text('Create Violation'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 36),
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
              style: TextStyle(
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
