class AnalyticsData {
  final String period;
  final int totalViolations;
  final Map<String, double> paymentStatus;
  final List<ViolationType> violationTypes;
  final List<MonthlyCount> monthlyCounts;
  final List<Location> topLocations;
  final List<RevenueTrend> revenueTrend;

  AnalyticsData({
    required this.period,
    required this.totalViolations,
    required this.paymentStatus,
    required this.violationTypes,
    required this.monthlyCounts,
    required this.topLocations, 
    required this.revenueTrend,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    // Handle payment status
    Map<String, double> paymentStatusMap = {};
    if (json['payment_status'] != null) {
      json['payment_status'].forEach((key, value) {
        paymentStatusMap[key] = value.toDouble();
      });
    }
    
    // Handle violation types
    List<ViolationType> violationTypesList = [];
    if (json['violation_types'] != null) {
      json['violation_types'].forEach((item) {
        violationTypesList.add(ViolationType.fromJson(item));
      });
    }
    
    // Handle monthly counts
    List<MonthlyCount> monthlyCountsList = [];
    if (json['monthly_counts'] != null) {
      json['monthly_counts'].forEach((item) {
        monthlyCountsList.add(MonthlyCount.fromJson(item));
      });
    }
    
    // Handle top locations
    List<Location> locationsList = [];
    if (json['top_locations'] != null) {
      json['top_locations'].forEach((item) {
        locationsList.add(Location.fromJson(item));
      });
    }
    
    // Handle revenue trend
    List<RevenueTrend> revenueTrendList = [];
    if (json['revenue_trend'] != null) {
      json['revenue_trend'].forEach((item) {
        revenueTrendList.add(RevenueTrend.fromJson(item));
      });
    }
    
    return AnalyticsData(
      period: json['period'] ?? '',
      totalViolations: json['total_violations'] ?? 0,
      paymentStatus: paymentStatusMap,
      violationTypes: violationTypesList,
      monthlyCounts: monthlyCountsList,
      topLocations: locationsList,
      revenueTrend: revenueTrendList,
    );
  }
}

class ViolationType {
  final String type;
  final int count;
  
  ViolationType({required this.type, required this.count});
  
  factory ViolationType.fromJson(Map<String, dynamic> json) {
    return ViolationType(
      type: json['type'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class MonthlyCount {
  final String month; // YYYY-MM or YYYY-MM-DD
  final int count;
  
  MonthlyCount({required this.month, required this.count});
  
  factory MonthlyCount.fromJson(Map<String, dynamic> json) {
    return MonthlyCount(
      month: json['month'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class Location {
  final String location;
  final int count;
  
  Location({required this.location, required this.count});
  
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      location: json['location'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class RevenueTrend {
  final String? month; // YYYY-MM
  final String? date;  // YYYY-MM-DD
  final double amount;
  
  RevenueTrend({this.month, this.date, required this.amount});
  
  factory RevenueTrend.fromJson(Map<String, dynamic> json) {
    return RevenueTrend(
      month: json['month'],
      date: json['date'],
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}
