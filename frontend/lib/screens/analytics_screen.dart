import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';
import '../utils/constants.dart';
import '../widgets/charts/violation_charts.dart';
import '../models/analytics_data.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    // Load analytics data when screen is first opened
    Future.microtask(() {
      Provider.of<AnalyticsProvider>(context, listen: false).fetchAnalyticsData();
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
              Provider.of<AnalyticsProvider>(context, listen: false).refresh();
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
                              analyticsProvider.selectedPeriod == Constants.periodWeek,
                              analyticsProvider.selectedPeriod == Constants.periodMonth,
                              analyticsProvider.selectedPeriod == Constants.periodYear,
                            ],
                            onPressed: (index) {
                              String period;
                              switch (index) {
                                case 0:
                                  period = Constants.periodWeek;
                                  break;
                                case 1:
                                  period = Constants.periodMonth;
                                  break;
                                case 2:
                                  period = Constants.periodYear;
                                  break;
                                default:
                                  period = Constants.periodMonth;
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
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Total Revenue',
                                '₹${analyticsData.totalRevenue.toStringAsFixed(2)}',
                                Icons.payments,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Pending',
                                analyticsData.pendingViolations.toString(),
                                Icons.pending_actions,
                                Colors.orange,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                context,
                                'Resolved',
                                analyticsData.resolvedViolations.toString(),
                                Icons.check_circle,
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
                
                // Violation types chart
                if (analyticsData.violationTypes.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildViolationTypeChart(analyticsData.violationTypes),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Monthly trend chart
                if (analyticsData.monthlyViolations.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildMonthlyTrendChart(analyticsData.monthlyViolations),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Revenue trend chart
                if (analyticsData.revenueTrend.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildRevenueTrendChart(analyticsData.revenueTrend),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSummaryItem(BuildContext context, String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          size: 36,
          color: color,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildViolationTypeChart(List<ViolationType> violationTypes) {
    return ViolationTypeChart(violationTypes: violationTypes);
  }
  
  Widget _buildMonthlyTrendChart(List<MonthlyCount> monthlyCounts) {
    return MonthlyTrendChart(monthlyCounts: monthlyCounts);
  }
  
  Widget _buildRevenueTrendChart(List<RevenueTrend> revenueTrend) {
    return RevenueTrendChart(revenueTrend: revenueTrend);
  }
}
