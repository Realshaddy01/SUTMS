import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tracking_provider.dart';

class MapFloatingButtons extends StatelessWidget {
  const MapFloatingButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'center_map',
            mini: true,
            onPressed: () {
              Provider.of<TrackingProvider>(context, listen: false)
                  .animateToCurrentLocation();
            },
            tooltip: 'My Location',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'refresh_map',
            mini: true,
            onPressed: () {
              Provider.of<TrackingProvider>(context, listen: false)
                  .fetchAllTrackingData();
            },
            tooltip: 'Refresh Data',
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'report_incident',
            backgroundColor: Colors.red,
            onPressed: () {
              _showReportIncidentDialog(context);
            },
            tooltip: 'Report Incident',
            child: const Icon(Icons.add_alert),
          ),
        ],
      ),
    );
  }
  
  void _showReportIncidentDialog(BuildContext context) {
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
    final currentLocation = trackingProvider.currentLocation;
    
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. Please try again.'),
        ),
      );
      return;
    }
    
    String incidentType = 'congestion';
    String description = '';
    int severity = 2;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Report Traffic Incident'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Incident Type:'),
                  DropdownButtonFormField<String>(
                    value: incidentType,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          incidentType = value;
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'accident',
                        child: Text('Traffic Accident'),
                      ),
                      DropdownMenuItem(
                        value: 'congestion',
                        child: Text('Traffic Congestion'),
                      ),
                      DropdownMenuItem(
                        value: 'roadwork',
                        child: Text('Road Work'),
                      ),
                      DropdownMenuItem(
                        value: 'hazard',
                        child: Text('Road Hazard'),
                      ),
                      DropdownMenuItem(
                        value: 'weather',
                        child: Text('Weather Condition'),
                      ),
                      DropdownMenuItem(
                        value: 'breakdown',
                        child: Text('Vehicle Breakdown'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other Incident'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Description:'),
                  TextFormField(
                    maxLines: 3,
                    onChanged: (value) {
                      description = value;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Provide details about the incident',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Severity:'),
                  Slider(
                    value: severity.toDouble(),
                    min: 1,
                    max: 4,
                    divisions: 3,
                    label: _getSeverityLabel(severity),
                    onChanged: (value) {
                      setState(() {
                        severity = value.round();
                      });
                    },
                  ),
                  Text(
                    'Severity: ${_getSeverityLabel(severity)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  if (description.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a description'),
                      ),
                    );
                    return;
                  }
                  
                  Navigator.of(context).pop();
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Reporting incident...'),
                        ],
                      ),
                    ),
                  );
                  
                  // Create incident data
                  final incidentData = {
                    'incident_type': incidentType,
                    'description': description,
                    'location': 'Reported via mobile app',
                    'latitude': currentLocation['latitude'],
                    'longitude': currentLocation['longitude'],
                    'severity': severity,
                  };
                  
                  // Submit incident report
                  final success = await trackingProvider.reportTrafficIncident(incidentData);
                  
                  // Hide loading indicator
                  Navigator.of(context).pop();
                  
                  // Show result
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Incident reported successfully'
                            : 'Failed to report incident. Please try again.',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                },
                child: const Text('REPORT'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  String _getSeverityLabel(int severity) {
    switch (severity) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Critical';
      default:
        return 'Medium';
    }
  }
}
