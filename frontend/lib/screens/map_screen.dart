import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/tracking_provider.dart';
import '../providers/map_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';
import 'components/map_control_panel.dart';
import 'components/statistics_panel.dart';
import 'components/map_floating_buttons.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isMapLoading = true;
  bool _showStatistics = false;
  bool _showControls = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tracking and map providers
    Future.delayed(Duration.zero, () {
      final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      
      trackingProvider.init();
      mapProvider.init();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final trackingProvider = Provider.of<TrackingProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffic Map'),
        elevation: Constants.appBarElevation,
        actions: [
          IconButton(
            icon: Icon(_showStatistics ? Icons.bar_chart : Icons.insert_chart),
            onPressed: () {
              setState(() {
                _showStatistics = !_showStatistics;
              });
            },
            tooltip: _showStatistics ? 'Hide Statistics' : 'Show Statistics',
          ),
          IconButton(
            icon: Icon(_showControls ? Icons.layers_clear : Icons.layers),
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            tooltip: _showControls ? 'Hide Map Controls' : 'Show Map Controls',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
            onSelected: (value) {
              _handleMoreOptions(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'filter',
                child: Text('Filter Data'),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Map Settings'),
              ),
              const PopupMenuItem<String>(
                value: 'help',
                child: Text('Map Legend'),
              ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Google Map with Heatmap Layer
          Consumer<TrackingProvider>(
            builder: (context, trackingProvider, _) {
              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: trackingProvider.initialCameraPosition,
                  zoom: Constants.defaultMapZoom,
                ),
                myLocationEnabled: trackingProvider.locationPermissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
                markers: trackingProvider.markers,
                onMapCreated: (GoogleMapController controller) {
                  trackingProvider.setMapController(controller);
                  mapProvider.setMapController(controller);
                  setState(() {
                    _isMapLoading = false;
                  });
                },
              );
            },
          ),
          
          // Heatmap Layer - Temporarily removed as package is not available
          Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              if (!mapProvider.showHotspots || mapProvider.hotspotPoints.isEmpty) {
                return const SizedBox.shrink();
              }
              
              // TODO: Implement alternative heatmap visualization
              return const SizedBox.shrink();
            },
          ),
          
          // Loading Indicator
          if (_isMapLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          
          // Map Control Panel
          if (_showControls)
            const MapControlPanel(),
          
          // Statistics Panel
          if (_showStatistics)
            const StatisticsPanel(),
          
          // Floating Buttons
          const MapFloatingButtons(),
        ],
      ),
    );
  }
  
  void _handleMoreOptions(String value) {
    switch (value) {
      case 'filter':
        _showFilterDialog();
        break;
      case 'settings':
        _showMapSettingsDialog();
        break;
      case 'help':
        _showMapLegendDialog();
        break;
    }
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Map Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<MapProvider>(
                builder: (context, mapProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Violation Type:'),
                      DropdownButton<String?>(
                        value: mapProvider.hotspotViolationType,
                        hint: const Text('All Types'),
                        isExpanded: true,
                        onChanged: (value) {
                          mapProvider.setHotspotViolationType(value);
                        },
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Types'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'speeding',
                            child: Text('Speeding'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'wrong_parking',
                            child: Text('Wrong Parking'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'red_light',
                            child: Text('Red Light'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'no_helmet',
                            child: Text('No Helmet'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'wrong_way',
                            child: Text('Wrong Way'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Consumer<TrackingProvider>(
                builder: (context, trackingProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nearby Radius:'),
                      Slider(
                        value: trackingProvider.nearbyRadius,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        label: '${trackingProvider.nearbyRadius.toStringAsFixed(1)} km',
                        onChanged: (value) {
                          trackingProvider.setNearbyRadius(value);
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CLOSE'),
          ),
          TextButton(
            onPressed: () {
              final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);
              final mapProvider = Provider.of<MapProvider>(context, listen: false);
              
              trackingProvider.fetchAllTrackingData();
              mapProvider.fetchHotspots();
              
              Navigator.of(context).pop();
            },
            child: const Text('APPLY & REFRESH'),
          ),
        ],
      ),
    );
  }
  
  void _showMapSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Map Type:'),
              DropdownButton<MapType>(
                value: MapType.normal,
                isExpanded: true,
                onChanged: (value) {
                  // TODO: Implement map type change
                },
                items: const [
                  DropdownMenuItem<MapType>(
                    value: MapType.normal,
                    child: Text('Normal'),
                  ),
                  DropdownMenuItem<MapType>(
                    value: MapType.satellite,
                    child: Text('Satellite'),
                  ),
                  DropdownMenuItem<MapType>(
                    value: MapType.terrain,
                    child: Text('Terrain'),
                  ),
                  DropdownMenuItem<MapType>(
                    value: MapType.hybrid,
                    child: Text('Hybrid'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Consumer<MapProvider>(
                builder: (context, mapProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Heatmap Opacity:'),
                      Slider(
                        value: 0.7,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        label: '70%',
                        onChanged: (value) {
                          // TODO: Implement heatmap opacity change
                        },
                      ),
                    ],
                  );
                },
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
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
  }
  
  void _showMapLegendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Legend'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                'Your Location',
                Colors.blue,
                Icons.my_location,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Officer',
                Colors.green,
                Icons.person,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Signal (Red)',
                Colors.red,
                Icons.traffic,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Signal (Green)',
                Colors.green,
                Icons.traffic,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Signal (Yellow)',
                Colors.amber,
                Icons.traffic,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Incident (Critical)',
                Colors.red.shade700,
                Icons.warning,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Incident (High)',
                Colors.red,
                Icons.warning,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Incident (Medium)',
                Colors.orange,
                Icons.warning,
              ),
              const SizedBox(height: 8),
              _buildLegendItem(
                'Traffic Incident (Low)',
                Colors.yellow,
                Icons.warning,
              ),
              const SizedBox(height: 16),
              const Text(
                'Heatmap:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.green,
                      Colors.yellow,
                      Colors.orange,
                      Colors.red,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Low'),
                  Text('High'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'The heatmap shows the density of traffic violations in the area.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
