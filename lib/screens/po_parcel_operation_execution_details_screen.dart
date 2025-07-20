import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/screens/po_activity_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoParcelOperationExecutionDetailsScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String username;

  const PoParcelOperationExecutionDetailsScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PoParcelOperationExecutionDetailsScreen> createState() =>
      _PoParcelOperationExecutionDetailsScreenState();
}

class _PoParcelOperationExecutionDetailsScreenState
    extends State<PoParcelOperationExecutionDetailsScreen> {
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myActivities = widget.parcelOperation.activities
        .where((activity) => activity.operatorId == widget.username)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operation Details'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          // Operation Details Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Execution ID:',
                      widget.parcelOperation.operationExecutionId,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Parcel:', widget.parcelOperation.parcelId),
                    if (widget.parcelOperation.assignedUsername != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Assigned PO:',
                        widget.parcelOperation.assignedUsername!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Activities List
          Expanded(
            child: myActivities.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: myActivities.length,
                    itemBuilder: (context, index) {
                      final activity = myActivities[index];
                      return _buildActivityCard(activity);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No activities yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your activities for this parcel will appear here',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final isOngoing = activity.endTime == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PoActivityDetailsScreen(
                activity: activity,
                jwtToken: widget.jwtToken,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Activity ${activity.id.substring(0, 8)}...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOngoing
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOngoing ? 'Ongoing' : 'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isOngoing
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Operator: ${activity.operatorId}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Start Time: ${DateFormat('yyyy-MM-dd HH:mm').format(activity.startTime)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (activity.endTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  'End Time: ${DateFormat('yyyy-MM-dd HH:mm').format(activity.endTime!)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
              if (activity.observations != null &&
                  activity.observations!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Observations: ${activity.observations}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (activity.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.photo_camera,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Photos: ${activity.photoUrls.length} attached',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
