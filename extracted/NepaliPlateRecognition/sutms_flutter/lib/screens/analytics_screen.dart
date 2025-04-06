import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sutms_flutter/providers/analytics_provider.dart';
import 'package:sutms_flutter/utils/constants.dart';
import 'package:sutms_flutter/widgets/charts/violation_charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsScreenState createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    // Load analytics data when screen is first opened
    Future.microtask(() {
      context.read<AnalyticsProvider>().fetchAnalyticsData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AnalyticsProvider>().refresh();
            },
          ),
        ],
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, analyticsProvider, child) {
          if (analyticsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (analyticsProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    analyticsProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      analyticsProvider.refresh();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }
          
          if (analyticsProvider.analyticsData == null) {
            return const Center(child: Text('No analytics data available'));
          }
          
          final analyticsData = analyticsProvider.analyticsData!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Period',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ToggleButtons(
                            isSelected: [
                              analyticsProvider.selectedPeriod == AppConstants.periodWeek,
                              analyticsProvider.selectedPeriod == AppConstants.periodMonth,
                              analyticsProvider.selectedPeriod == AppConstants.periodQuarter,
                              analyticsProvider.selectedPeriod == AppConstants.periodYear,
                            ],
                            onPressed: (index) {
                              String period;
                              switch (index) {
                                case 0:
                                  period = AppConstants.periodWeek;
                                  break;
                                case 1:
                                  period = AppConstants.periodMonth;
                                  break;
                                case 2:
                                  period = AppConstants.periodQuarter;
                                  break;
                                case 3:
                                  period = AppConstants.periodYear;
                                  break;
                                default:
                                  period = AppConstants.periodMonth;
                              }
                              analyticsProvider.setPeriod(period);
                            },
                            borderRadius: BorderRadius.circular(8),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Weekly'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Monthly'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Quarterly'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Yearly'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Total Violations',
                                analyticsData.totalViolations.toString(),
                                Icons.report_problem,
                                Colors.orange,
                              ),
                            ),
                            if (analyticsData.paymentStatus.containsKey('paid'))
                              Expanded(
                                child: _buildSummaryItem(
                                  context,
                                  'Paid',
                                  '${analyticsData.paymentStatus['paid']!.toStringAsFixed(1)}%',
                                  Icons.payments,
                                  Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Payment status chart
                if (analyticsData.paymentStatus.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: PaymentStatusPieChart(
                        paymentStatus: analyticsData.paymentStatus,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Violation types chart
                if (analyticsData.violationTypes.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ViolationTypeBarChart(
                        violationTypes: analyticsData.violationTypes,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Monthly trend chart
                if (analyticsData.monthlyCounts.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MonthlyTrendLineChart(
                        monthlyCounts: analyticsData.monthlyCounts,
                        period: analyticsData.period,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Revenue trend chart
                if (analyticsData.revenueTrend.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: RevenueTrendChart(
                        revenueTrend: analyticsData.revenueTrend,
                        period: analyticsData.period,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Top locations list
                if (analyticsData.topLocations.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Top Violation Locations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...analyticsData.topLocations.map((location) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      location.location,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      location.count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSummaryItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
