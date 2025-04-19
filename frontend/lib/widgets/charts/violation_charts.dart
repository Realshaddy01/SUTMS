import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/analytics_data.dart';

class PaymentStatusPieChart extends StatelessWidget {
  final Map<String, double> paymentStatus;
  
  const PaymentStatusPieChart({Key? key, required this.paymentStatus}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (paymentStatus.isEmpty) {
      return const Center(child: Text('No payment data available'));
    }
    
    // Define fixed colors for different status types
    final Map<String, Color> statusColors = {
      'paid': Colors.green,
      'pending': Colors.orange,
      'disputed': Colors.red,
    };
    
    List<PieChartSectionData> sections = [];
    
    paymentStatus.forEach((key, value) {
      sections.add(
        PieChartSectionData(
          color: statusColors[key] ?? Colors.grey,
          value: value,
          title: '$key\n${value.toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });
    
    return Column(
      children: [
        const Text(
          'Payment Status',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              startDegreeOffset: 180,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: statusColors.entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: entry.value,
                ),
                const SizedBox(width: 4),
                Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class ViolationTypeChart extends StatelessWidget {
  final List<ViolationType> violationTypes;
  
  const ViolationTypeChart({Key? key, required this.violationTypes}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (violationTypes.isEmpty) {
      return const Center(child: Text('No violation type data available'));
    }
    
    // Sort violation types by count (highest first)
    final sortedTypes = List<ViolationType>.from(violationTypes)
      ..sort((a, b) => b.count.compareTo(a.count));
      
    // Take top 5 for readability
    final topTypes = sortedTypes.take(5).toList();
    
    return Column(
      children: [
        const Text(
          'Top Violation Types',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: ListView.builder(
            itemCount: topTypes.length,
            itemBuilder: (context, index) {
              final item = topTypes[index];
              final double percentage = item.count / sortedTypes.first.count;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          item.count.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.blue.shade100,
                      color: Colors.blue,
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MonthlyTrendChart extends StatelessWidget {
  final List<MonthlyCount> monthlyCounts;
  
  const MonthlyTrendChart({Key? key, required this.monthlyCounts}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (monthlyCounts.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }
    
    // Sort monthly counts by date
    final sortedCounts = List<MonthlyCount>.from(monthlyCounts)
      ..sort((a, b) => a.month.compareTo(b.month));
    
    final maxCount = sortedCounts.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: [
        const Text(
          'Monthly Violations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              itemCount: sortedCounts.length,
              itemBuilder: (context, index) {
                final item = sortedCounts[index];
                final double percentage = item.count / maxCount;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.month,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            item.count.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.green.shade100,
                        color: Colors.green,
                        minHeight: 8,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class RevenueTrendChart extends StatelessWidget {
  final List<RevenueTrend> revenueTrend;
  
  const RevenueTrendChart({Key? key, required this.revenueTrend}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (revenueTrend.isEmpty) {
      return const Center(child: Text('No revenue data available'));
    }
    
    // Sort revenue by date
    final sortedRevenue = List<RevenueTrend>.from(revenueTrend)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final maxAmount = sortedRevenue.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: [
        const Text(
          'Revenue Trend',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              itemCount: sortedRevenue.length,
              itemBuilder: (context, index) {
                final item = sortedRevenue[index];
                final double percentage = item.amount / maxAmount;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.date,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '₹${item.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.orange.shade100,
                        color: Colors.orange,
                        minHeight: 8,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
