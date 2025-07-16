import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class ActivityDetailsScreen extends StatelessWidget {
  final Activity activity;
  final String jwtToken;

  const ActivityDetailsScreen({
    super.key,
    required this.activity,
    required this.jwtToken,
  });

  @override
  Widget build(BuildContext context) {
    // Helper to format dates and times
    String formatDateTime(DateTime? dt) {
      if (dt == null) return 'N/A';
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Make the card size fit content
              children: [
                _buildDetailRow('Activity ID:', activity.id),
                const Divider(),
                _buildDetailRow('Operator:', activity.operatorId),
                const Divider(),
                _buildDetailRow('Start Time:', formatDateTime(activity.startTime)),
                const Divider(),
                _buildDetailRow('End Time:', formatDateTime(activity.endTime)),
                const Divider(),
                // This part ensures observations are shown if they exist
                if (activity.observations != null &&
                    activity.observations!.isNotEmpty) ...[
                  _buildDetailRow('Observations:', activity.observations!),
                  const Divider(),
                ],
                if (activity.photoUrls.isNotEmpty)
                  _buildDetailRow(
                      'Photos:', activity.photoUrls.length.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build a styled row for details
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}