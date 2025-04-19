class AnalyticsData {
  final List<ViolationType> violationTypes;
  final List<MonthlyCount> monthlyViolations;
  final List<RevenueTrend> revenueTrend;
  final int totalViolations;
  final double totalRevenue;
  final int pendingViolations;
  final int resolvedViolations;

  AnalyticsData({
    required this.violationTypes,
    required this.monthlyViolations,
    required this.revenueTrend,
    required this.totalViolations,
    required this.totalRevenue,
    required this.pendingViolations,
    required this.resolvedViolations,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      violationTypes: (json['violation_types'] as List)
          .map((type) => ViolationType.fromJson(type))
          .toList(),
      monthlyViolations: (json['monthly_violations'] as List)
          .map((month) => MonthlyCount.fromJson(month))
          .toList(),
      revenueTrend: (json['revenue_trend'] as List)
          .map((trend) => RevenueTrend.fromJson(trend))
          .toList(),
      totalViolations: json['total_violations'],
      totalRevenue: json['total_revenue'].toDouble(),
      pendingViolations: json['pending_violations'],
      resolvedViolations: json['resolved_violations'],
    );
  }
}

class ViolationType {
  final String name;
  final int count;

  ViolationType({
    required this.name,
    required this.count,
  });

  factory ViolationType.fromJson(Map<String, dynamic> json) {
    return ViolationType(
      name: json['name'],
      count: json['count'],
    );
  }
}

class MonthlyCount {
  final String month;
  final int count;

  MonthlyCount({
    required this.month,
    required this.count,
  });

  factory MonthlyCount.fromJson(Map<String, dynamic> json) {
    return MonthlyCount(
      month: json['month'],
      count: json['count'],
    );
  }
}

class RevenueTrend {
  final String date;
  final double amount;

  RevenueTrend({
    required this.date,
    required this.amount,
  });

  factory RevenueTrend.fromJson(Map<String, dynamic> json) {
    return RevenueTrend(
      date: json['date'],
      amount: json['amount'].toDouble(),
    );
  }
}
