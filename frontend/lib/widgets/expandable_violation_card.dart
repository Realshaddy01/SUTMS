import 'package:flutter/material.dart';

/// Widget for expandable violation card
class ExpandableViolationCard extends StatelessWidget {
  final Map<String, dynamic> violation;

  const ExpandableViolationCard({super.key, required this.violation});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          violation['violation_type'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${violation['timestamp'].toString().split('T')[0]} • ${violation['status']}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Location', violation['location']),
                _buildDetailRow('Date', violation['timestamp'].toString().split('T')[0]),
                _buildDetailRow('Time', violation['timestamp'].toString().split('T')[1].substring(0, 5)),
                _buildDetailRow('Fine Amount', '₹${violation['fine_amount']}'),
                _buildDetailRow('Status', violation['status']),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to violation details
                    Navigator.pushNamed(
                      context,
                      '/violation-details',
                      arguments: {'violation_id': violation['id']},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 