import 'package:flutter/material.dart';
import '../models/violation.dart';
import 'package:intl/intl.dart';

class ViolationCard extends StatelessWidget {
  final Violation violation;
  final VoidCallback? onTap;
  final bool canPay;
  final bool showStatusBadge;
  final bool compact;

  const ViolationCard({
    Key? key,
    required this.violation,
    this.onTap,
    this.canPay = false,
    this.showStatusBadge = true,
    this.compact = false,
  }) : super(key: key);

  Color _getStatusColor() {
    if (violation.status == 'PENDING') return Colors.orange;
    if (violation.status == 'CONFIRMED') return Colors.blue;
    if (violation.status == 'CONTESTED') return Colors.purple;
    if (violation.status == 'RESOLVED') return Colors.green;
    if (violation.status == 'CANCELLED') return Colors.red;
    return Colors.grey;
  }

  String get statusDisplay {
    if (violation.status == 'PENDING') return 'Pending';
    if (violation.status == 'CONFIRMED') return 'Confirmed';
    if (violation.status == 'CONTESTED') return 'Contested';
    if (violation.status == 'RESOLVED') return 'Resolved';
    if (violation.status == 'CANCELLED') return 'Cancelled';
    return violation.status;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');
    final fineFormat = NumberFormat.currency(symbol: '\$');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      violation.violationType.isEmpty 
                          ? 'Unknown Violation'
                          : violation.violationTypeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showStatusBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        statusDisplay,
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (!compact) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(violation.createdAtDate),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          violation.location != null
                            ? (violation.location!.length > 15 
                                ? violation.location!.substring(0, 15) 
                                : violation.location!)
                            : 'N/A',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_car, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        violation.licensePlate ?? 'Unknown',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        fineFormat.format(violation.fineAmount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 