import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/screens/po_activity_management_screen.dart';
import 'package:trailblaze_app/screens/po_live_tracking_map_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoParcelActivityScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String username;
  final String workSheetId;

  const PoParcelActivityScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.username,
    required this.workSheetId,
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
    setState(() {
      _myActivities = widget.parcelOperation.activities
          .where((activity) => activity.operatorId == widget.username)
          .toList();
      _myActivities.sort((a, b) => b.startTime.compareTo(a.startTime));
    });
  }

  Future<void> _startNewActivity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Activity'),
        content: const Text('Are you sure you want to start a new activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ExecutionService.startActivity(
        operationExecutionId: widget.parcelOperation.operationExecutionId,
        parcelOperationExecutionId: widget.parcelOperation.id,
        jwtToken: widget.jwtToken,
      );
      _showSnackBar('Activity started successfully.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to start activity: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      _showSnackBar('Activity stopped successfully.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to stop activity: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToActivityManagement(Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoActivityManagementScreen(
          activity: activity,
          jwtToken: widget.jwtToken,
          isOngoing: activity.endTime == null,
        ),
      ),
    ).then((result) {
      if (result == true) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _navigateToLiveTrackingMap(Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoLiveTrackingMapScreen(
          parcelOperation: widget.parcelOperation,
          jwtToken: widget.jwtToken,
          assignedWorkSheetId: widget.workSheetId,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ongoingActivity = _myActivities
        .where((activity) => activity.endTime == null)
        .cast<Activity?>()
        .firstWhere((_) => true, orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        title: Text('Parcel ${widget.parcelOperation.parcelId}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                        widget.parcelOperation.operationExecution?.name ??
                            'Operation ${widget.parcelOperation.operationExecutionId}',
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
                      const SizedBox(height: 16),
                      if (ongoingActivity == null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _startNewActivity,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start New Activity'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
            'Start your first activity for this parcel',
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
            const SizedBox(height: 12),
            if (isOngoing)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _stopActivity(activity),
                      icon: const Icon(Icons.stop_circle_outlined, size: 20),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _navigateToLiveTrackingMap(activity),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('Track'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                ],
              ),
            if (!isOngoing)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToActivityManagement(activity),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: const Text('View & Add Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                  ),
                ),
              ),
          ],
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
}
