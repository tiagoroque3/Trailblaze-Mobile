import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/screens/po_activity_management_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoParcelActivityScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String username;

  const PoParcelActivityScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PoParcelActivityScreen> createState() => _PoParcelActivityScreenState();
}

class _PoParcelActivityScreenState extends State<PoParcelActivityScreen> {
  bool _isLoading = false;
  List<Activity> _myActivities = [];

  @override
  void initState() {
    super.initState();
    _loadMyActivities();
  }

  void _loadMyActivities() {
    _myActivities = widget.parcelOperation.activities
        .where((activity) => activity.operatorId == widget.username)
        .toList();
    
    // Sort by start time, most recent first
    _myActivities.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  Future<void> _startNewActivity() async {
    // Check if there's already an ongoing activity
    final ongoingActivity = _myActivities.firstWhere(
      (activity) => activity.endTime == null,
      orElse: () => null as dynamic,
    );

    if (ongoingActivity != null) {
      _showSnackBar('You already have an ongoing activity for this parcel', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ExecutionService.startActivity(
        operationExecutionId: widget.parcelOperation.operationExecutionId,
        parcelOperationExecutionId: widget.parcelOperation.id,
        jwtToken: widget.jwtToken,
      );

      _showSnackBar('Activity started successfully');
      Navigator.of(context).pop(true); // Return to previous screen to refresh
    } catch (e) {
      _showSnackBar('Failed to start activity: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _stopActivity(Activity activity) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ExecutionService.stopActivity(
        operationExecutionId: widget.parcelOperation.operationExecutionId,
        activityId: activity.id,
        jwtToken: widget.jwtToken,
      );

      _showSnackBar('Activity stopped successfully');
      Navigator.of(context).pop(true); // Return to previous screen to refresh
    } catch (e) {
      _showSnackBar('Failed to stop activity: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
    final ongoingActivity = _myActivities.firstWhere(
      (activity) => activity.endTime == null,
      orElse: () => null as dynamic,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Parcel ${widget.parcelOperation.parcelId}'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (ongoingActivity != null)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              onPressed: _isLoading ? null : () => _stopActivity(ongoingActivity),
              tooltip: 'Stop Current Activity',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.parcelOperation.operationExecution?.name ?? 'Unknown Operation',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          _buildStatusChip(widget.parcelOperation.status),
                        ],
                      ),
                      if (ongoingActivity != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_circle,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Activity in progress since ${DateFormat('HH:mm').format(ongoingActivity.startTime)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Activities list
                Expanded(
                  child: _myActivities.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _myActivities.length,
                          itemBuilder: (context, index) {
                            final activity = _myActivities[index];
                            return _buildActivityCard(activity);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: ongoingActivity == null
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _startNewActivity,
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Activity'),
            )
          : null,
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your first activity for this parcel',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final isOngoing = activity.endTime == null;
    final duration = isOngoing
        ? DateTime.now().difference(activity.startTime)
        : activity.endTime!.difference(activity.startTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PoActivityManagementScreen(
                activity: activity,
                jwtToken: widget.jwtToken,
                isOngoing: isOngoing,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy').format(activity.startTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('HH:mm').format(activity.startTime)} - ${isOngoing ? 'Ongoing' : DateFormat('HH:mm').format(activity.endTime!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActivityStatusChip(isOngoing),
                ],
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              if (activity.observations != null && activity.observations!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.observations!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              
              if (activity.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.photo_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activity.photoUrls.length} photo${activity.photoUrls.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOngoing ? 'Tap to stop or add info' : 'Tap to view details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    
    switch (status.toUpperCase()) {
      case 'ASSIGNED':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'EXECUTED':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
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

  Widget _buildActivityStatusChip(bool isOngoing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOngoing ? Colors.blue.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isOngoing ? 'Ongoing' : 'Completed',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOngoing ? Colors.blue.shade800 : Colors.green.shade800,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}