
class ViolationAppeal {
  final int id;
  final int violationId;
  final int appealedById;
  final String reason;
  final String? evidenceFileUrl;
  final String status;
  final int? reviewedById;
  final DateTime? reviewDate;
  final String? reviewNotes;
  final DateTime createdAt;

  ViolationAppeal({
    required this.id,
    required this.violationId,
    required this.appealedById,
    required this.reason,
    this.evidenceFileUrl,
    required this.status,
    this.reviewedById,
    this.reviewDate,
    this.reviewNotes,
    required this.createdAt,
  });

  // Status getters
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  // Create from JSON
  factory ViolationAppeal.fromJson(Map<String, dynamic> json) {
    return ViolationAppeal(
      id: json['id'],
      violationId: json['violation'],
      appealedById: json['appealed_by'],
      reason: json['reason'],
      evidenceFileUrl: json['evidence_file'],
      status: json['status'],
      reviewedById: json['reviewed_by'],
      reviewDate: json['review_date'] != null ? DateTime.parse(json['review_date']) : null,
      reviewNotes: json['review_notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'violation': violationId,
      'appealed_by': appealedById,
      'reason': reason,
      'evidence_file': evidenceFileUrl,
      'status': status,
      'reviewed_by': reviewedById,
      'review_date': reviewDate?.toIso8601String(),
      'review_notes': reviewNotes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Copy with
  ViolationAppeal copyWith({
    int? id,
    int? violationId,
    int? appealedById,
    String? reason,
    String? evidenceFileUrl,
    String? status,
    int? reviewedById,
    DateTime? reviewDate,
    String? reviewNotes,
    DateTime? createdAt,
  }) {
    return ViolationAppeal(
      id: id ?? this.id,
      violationId: violationId ?? this.violationId,
      appealedById: appealedById ?? this.appealedById,
      reason: reason ?? this.reason,
      evidenceFileUrl: evidenceFileUrl ?? this.evidenceFileUrl,
      status: status ?? this.status,
      reviewedById: reviewedById ?? this.reviewedById,
      reviewDate: reviewDate ?? this.reviewDate,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ViolationAppeal{id: $id, violationId: $violationId, status: $status}';
  }
} 