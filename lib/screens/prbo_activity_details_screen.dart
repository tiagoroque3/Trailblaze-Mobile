import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/widgets/photo_gallery_widget.dart';

class PrboActivityDetailsScreen extends StatefulWidget {
  final Activity activity;
  final String jwtToken;
  final String username;
  final bool canEdit;

  const PrboActivityDetailsScreen({
    super.key,
    required this.activity,
    required this.jwtToken,
    required this.username,
    this.canEdit = true,
  });

  @override
  _PrboActivityDetailsScreenState createState() =>
      _PrboActivityDetailsScreenState();
}

class _PrboActivityDetailsScreenState extends State<PrboActivityDetailsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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
                  children: [
                    Text(
                      'Activity Information',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Activity ID:', widget.activity.id),
                    const Divider(),
                    _buildDetailRow('Operator:', widget.activity.operatorId),
                    const Divider(),
                    _buildDetailRow(
                      'Start Time:',
                      formatDateTime(widget.activity.startTime),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      'End Time:',
                      formatDateTime(widget.activity.endTime),
                    ),
                    const Divider(),
                    _buildDetailRow('Status:', _getActivityStatus()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Photos Section
            PhotoGalleryWidget(
              photoUrls: widget.activity.photoUrls,
              jwtToken: widget.jwtToken,
              activityId: widget.activity.id,
              canEdit: false, // PRBO cannot edit photos, only view
            ),
          ],
        ),
      ),
    );
  }

  String _getActivityStatus() {
    if (widget.activity.endTime == null) {
      return 'In Progress';
    } else {
      return 'Completed';
    }
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
