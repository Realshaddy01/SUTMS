import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import '../../providers/map_provider.dart';
import '../../utils/constants.dart';

class StatisticsPanel extends StatefulWidget {
  const StatisticsPanel({Key? key}) : super(key: key);

  @override
  State<StatisticsPanel> createState() => _StatisticsPanelState();
}

class _StatisticsPanelState extends State<StatisticsPanel> {
  bool _isLoading = false;
  Map<String, dynamic> _summaryStats = {};
  List<dynamic> _violationsByType = [];
  String _selectedPeriod = Constants.periodMonth;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      
      // Load summary stats
      final summaryStats = await mapProvider.fetchSummaryStats();
      
      // Load violations by type
      final violationsByType = await mapProvider.fetchViolationStats(
        period: _selectedPeriod,
      );
      
      setState(() {
        _summaryStats = summaryStats;
        _violationsByType = violationsByType['violations_by_type'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 16,
      child: Container(
        width: 300,
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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Statistics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadStats,
                    tooltip: 'Refresh Statistics',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                children: [
                  _buildSummaryStats(),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Violations by Type',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            DropdownButton<String>(
                              value: _selectedPeriod,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedPeriod = value;
                                  });
                                  _loadStats();
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: Constants.periodToday,
                                  child: Text('Today'),
                                ),
                                DropdownMenuItem(
                                  value: Constants.periodWeek,
                                  child: Text('Week'),
                                ),
                                DropdownMenuItem(
                                  value: Constants.periodMonth,
                                  child: Text('Month'),
                                ),
                                DropdownMenuItem(
                                  value: Constants.periodYear,
                                  child: Text('Year'),
                                ),
                                DropdownMenuItem(
                                  value: Constants.periodAll,
                                  child: Text('All'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildViolationTypeChart(),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryStats() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                title: 'Total Violations',
                value: _summaryStats['total_violations']?.toString() ?? '0',
                icon: Icons.warning,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Pending',
                value: _summaryStats['pending_violations']?.toString() ?? '0',
                icon: Icons.pending,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'Paid',
                value: _summaryStats['paid_violations']?.toString() ?? '0',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                title: 'Total Fines',
                value: 'Rs. ${_formatNumber(_summaryStats['total_fines'] ?? 0)}',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'Incidents',
                value: _summaryStats['active_incidents']?.toString() ?? '0',
                icon: Icons.warning_amber,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildViolationTypeChart() {
    if (_violationsByType.isEmpty) {
      return const Center(
        child: Text('No violation data available'),
      );
    }
    
    final data = _violationsByType.map((item) {
      return ViolationData(
        item['violation_type'] ?? 'Unknown',
        item['count'] ?? 0,
      );
    }).toList();
    
    final series = [
      charts.Series<ViolationData, String>(
        id: 'Violations',
        domainFn: (ViolationData data, _) => data.type,
        measureFn: (ViolationData data, _) => data.count,
        colorFn: (_, index) => charts.MaterialPalette.blue.shadeDefault,
        data: data,
        labelAccessorFn: (ViolationData data, _) => '${data.count}',
      ),
    ];
    
    return SizedBox(
      height: 200,
      child: charts.BarChart(
        series,
        animate: true,
        vertical: false,
        barRendererDecorator: charts.BarLabelDecorator<String>(),
        domainAxis: const charts.OrdinalAxisSpec(
          renderSpec: charts.SmallTickRendererSpec(
            labelRotation: 0,
          ),
        ),
      ),
    );
  }
  
  String _formatNumber(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }
}

class ViolationData {
  final String type;
  final int count;
  
  ViolationData(this.type, this.count);
}
