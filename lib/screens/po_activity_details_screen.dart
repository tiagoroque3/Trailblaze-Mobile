import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/widgets/photo_gallery_widget.dart';

class PoActivityDetailsScreen extends StatelessWidget {
  final Activity activity;
  final String jwtToken;

  const PoActivityDetailsScreen({
    super.key,
    required this.activity,
    required this.jwtToken,
  });

  void _addObservation(BuildContext context) {
    // TODO: Implement the UI and logic to add an observation.
    // This could be a dialog with a text field that calls a new API endpoint.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add observation functionality to be implemented.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formatDateTime(DateTime? dt) {
      if (dt == null) return 'N/A';
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Basic Activity Information
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('Activity ID:', activity.id),
                    const Divider(),
                    _buildDetailRow('Operator:', activity.operatorId),
                    const Divider(),
                    _buildDetailRow(
                      'Start Time:',
                      formatDateTime(activity.startTime),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'End Time:',
                      formatDateTime(activity.endTime),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'Status:',
                      activity.endTime != null ? 'Completed' : 'Ongoing',
                    ),
                    if (activity.observations != null &&
                        activity.observations!.isNotEmpty) ...[
                      const Divider(),
                      _buildDetailRow('Observations:', activity.observations!),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Photos Section
            PhotoGalleryWidget(
              photoUrls: activity.photoUrls,
              jwtToken: jwtToken,
              activityId: activity.id,
              canEdit: true, // PO can edit photos
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addObservation(context),
        backgroundColor: AppColors.primaryGreen,
        tooltip: 'Add Observation',
        child: const Icon(Icons.add_comment),
      ),
    );
  }

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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
