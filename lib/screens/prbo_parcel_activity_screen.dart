import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/prbo_activity_details_screen.dart';
import 'package:trailblaze_app/services/prbo_execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PrboParcelActivityScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperationExecution;
  final String jwtToken;
  final String username;

  const PrboParcelActivityScreen({
    Key? key,
    required this.parcelOperationExecution,
    required this.jwtToken,
    required this.username,
  }) : super(key: key);

  @override
  _PrboParcelActivityScreenState createState() =>
      _PrboParcelActivityScreenState();
}

class _PrboParcelActivityScreenState extends State<PrboParcelActivityScreen> {
  late Future<List<Activity>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _refreshActivities();
  }

  void _refreshActivities() {
    setState(() {
      _activitiesFuture = _fetchActivities();
    });
  }

  Future<List<Activity>> _fetchActivities() async {
    try {
      if (widget.parcelOperationExecution.operationExecution?.id != null) {
        return await PrboExecutionService.fetchActivitiesForOperationParcel(
          operationExecutionId:
              widget.parcelOperationExecution.operationExecution!.id,
          parcelOperationExecutionId: widget.parcelOperationExecution.id,
          jwtToken: widget.jwtToken,
        );
      } else {
        // Return cached activities if no execution ID available
        return widget.parcelOperationExecution.activities;
      }
    } catch (e) {
      // Fall back to cached activities
      return widget.parcelOperationExecution.activities;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime.toLocal());
  }

  Widget _buildActivityStatusChip(Activity activity) {
    Color backgroundColor;
    Color textColor;
    String status;

    if (activity.endTime == null) {
      status = 'In Progress';
      backgroundColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    } else {
      status = 'Completed';
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActivityActions(Activity activity) {
    List<Widget> actions = [];

    // View details button
    actions.add(
      OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrboActivityDetailsScreen(
                activity: activity,
                jwtToken: widget.jwtToken,
                username: widget.username,
                canEdit: true, // PRBO can edit activities
              ),
            ),
          ).then((_) => _refreshActivities());
        },
        icon: const Icon(Icons.info_outline, size: 18),
        label: const Text('Details'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.parcelOperationExecution.operationExecution;

    return Scaffold(
      appBar: AppBar(
        title: Text('Parcel ${widget.parcelOperationExecution.parcelId}'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshActivities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Operation Info Card
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
                    Text(
                      'Operation Details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Operation ID:', operation?.id ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Parcel:',
                      widget.parcelOperationExecution.parcelId,
                    ),
                    if (widget.parcelOperationExecution.assignedUsername !=
                        null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Assigned PO:',
                        widget.parcelOperationExecution.assignedUsername!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Activities List
          Expanded(
            child: FutureBuilder<List<Activity>>(
              future: _activitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading activities',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshActivities,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data ?? [];

                if (activities.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildActivitiesList(activities);
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
          Icon(Icons.work_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No activities found',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'This parcel doesn\'t have any activities yet',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList(List<Activity> activities) {
    return RefreshIndicator(
      onRefresh: () async => _refreshActivities(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          return _buildActivityCard(activities[index]);
        },
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Activity ${activity.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                _buildActivityStatusChip(activity),
              ],
            ),

            const SizedBox(height: 12),

            // Activity Details
            Column(
              children: [
                _buildDetailRow('Operator:', activity.operatorId),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Start Time:',
                  _formatDateTime(activity.startTime),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('End Time:', _formatDateTime(activity.endTime)),
                if (activity.observations != null &&
                    activity.observations!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Observations:', activity.observations!),
                ],
                if (activity.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Photos:',
                    '${activity.photoUrls.length} attached',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            _buildActivityActions(activity),
          ],
        ),
      ),
    );
  }
}
