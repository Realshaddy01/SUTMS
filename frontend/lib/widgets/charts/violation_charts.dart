import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sutms_flutter/models/analytics_data.dart';

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

class ViolationTypeBarChart extends StatelessWidget {
  final List<ViolationType> violationTypes;
  
  const ViolationTypeBarChart({Key? key, required this.violationTypes}) : super(key: key);
  
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
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topTypes.first.count * 1.2, // 20% buffer on top
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      // Show abbreviated titles on the x-axis
                      if (value.toInt() >= 0 && value.toInt() < topTypes.length) {
                        String title = topTypes[value.toInt()].type;
                        if (title.length > 10) {
                          title = title.substring(0, 8) + '...';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: topTypes.first.count / 5,
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                topTypes.length,
                (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: topTypes[index].count.toDouble(),
                        color: Colors.blue.shade300,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MonthlyTrendLineChart extends StatelessWidget {
  final List<MonthlyCount> monthlyCounts;
  final String period;
  
  const MonthlyTrendLineChart({Key? key, required this.monthlyCounts, required this.period}) : super(key: key);
  
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
        Text(
          period == 'week' ? 'Daily Trend' : 'Monthly Trend',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxCount / 5,
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedCounts.length) {
                        String date = sortedCounts[value.toInt()].month;
                        // Format the date for display
                        if (period == 'week') {
                          // For weekly view, show day-month
                          if (date.length >= 10) {
                            date = date.substring(8, 10) + '-' + date.substring(5, 7);
                          }
                        } else {
                          // For monthly view, show month-year
                          if (date.length >= 7) {
                            date = date.substring(5, 7) + '-' + date.substring(2, 4);
                          }
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.shade300),
              ),
              minX: 0,
              maxX: sortedCounts.length - 1,
              minY: 0,
              maxY: maxCount * 1.2, // Add 20% buffer at top
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    sortedCounts.length,
                    (index) => FlSpot(
                      index.toDouble(),
                      sortedCounts[index].count.toDouble(),
                    ),
                  ),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RevenueTrendChart extends StatelessWidget {
  final List<RevenueTrend> revenueTrend;
  final String period;
  
  const RevenueTrendChart({Key? key, required this.revenueTrend, required this.period}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (revenueTrend.isEmpty) {
      return const Center(child: Text('No revenue data available'));
    }
    
    // Sort revenue by date
    final sortedRevenue = List<RevenueTrend>.from(revenueTrend)
      ..sort((a, b) {
        String aDate = a.date ?? a.month ?? '';
        String bDate = b.date ?? b.month ?? '';
        return aDate.compareTo(bDate);
      });
    
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
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAmount * 1.2, // 20% buffer on top
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < sortedRevenue.length) {
                        String date = period == 'week' 
                            ? (sortedRevenue[value.toInt()].date ?? '')
                            : (sortedRevenue[value.toInt()].month ?? '');
                            
                        // Format the date for display
                        if (period == 'week') {
                          // For weekly view, show day-month
                          if (date.length >= 10) {
                            date = date.substring(8, 10) + '-' + date.substring(5, 7);
                          }
                        } else {
                          // For monthly view, show month-year
                          if (date.length >= 7) {
                            date = date.substring(5, 7) + '-' + date.substring(2, 4);
                          }
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxAmount / 5,
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(
                sortedRevenue.length,
                (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: sortedRevenue[index].amount,
                        color: Colors.green.shade400,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
