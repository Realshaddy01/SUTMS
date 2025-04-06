import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tracking_provider.dart';
import '../../providers/map_provider.dart';
import '../../utils/constants.dart';

class MapControlPanel extends StatelessWidget {
  const MapControlPanel({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final trackingProvider = Provider.of<TrackingProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    
    return Positioned(
      left: 16,
      top: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Map Layers',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Officers'),
              value: trackingProvider.showOfficers,
              onChanged: (value) {
                trackingProvider.toggleOfficersDisplay();
              },
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            SwitchListTile(
              title: const Text('Traffic Signals'),
              value: trackingProvider.showTrafficSignals,
              onChanged: (value) {
                trackingProvider.toggleTrafficSignalsDisplay();
              },
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            SwitchListTile(
              title: const Text('Incidents'),
              value: trackingProvider.showIncidents,
              onChanged: (value) {
                trackingProvider.toggleIncidentsDisplay();
              },
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            SwitchListTile(
              title: const Text('Violation Hotspots'),
              value: mapProvider.showHotspots,
              onChanged: (value) {
                mapProvider.toggleHotspots();
              },
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hotspot Period',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: mapProvider.hotspotPeriod,
                    onChanged: (value) {
                      if (value != null) {
                        mapProvider.setHotspotPeriod(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: Constants.periodToday,
                        child: Text('Today'),
                      ),
                      DropdownMenuItem(
                        value: Constants.periodWeek,
                        child: Text('Past Week'),
                      ),
                      DropdownMenuItem(
                        value: Constants.periodMonth,
                        child: Text('Past Month'),
                      ),
                      DropdownMenuItem(
                        value: Constants.periodYear,
                        child: Text('Past Year'),
                      ),
                      DropdownMenuItem(
                        value: Constants.periodAll,
                        child: Text('All Time'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
