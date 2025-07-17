import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

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
            if (widget.activity.photoUrls.isNotEmpty) ...[
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
                      Row(
                        children: [
                          const Text(
                            'Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${widget.activity.photoUrls.length} photo(s)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // In a real implementation, you would display actual photos here
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library,
                                size: 32,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Photos will be displayed here',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
