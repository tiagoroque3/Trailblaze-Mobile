import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/services/execution_sheet_service.dart';
import 'package:trailblaze_app/screens/po_activity_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoParcelOperationDetailsScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String username;

  const PoParcelOperationDetailsScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PoParcelOperationDetailsScreen> createState() => _PoParcelOperationDetailsScreenState();
}

class _PoParcelOperationDetailsScreenState extends State<PoParcelOperationDetailsScreen> {
  late ParcelOperationExecution _parcelOperation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _parcelOperation = widget.parcelOperation;
  }

  Future<void> _startActivity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ExecutionSheetService.startActivity(
        operationExecutionId: _parcelOperation.operationExecutionId,
        parcelOperationExecutionId: _parcelOperation.id,
        jwtToken: widget.jwtToken,
      );

      if (success) {
        _showSuccessSnackBar('Activity started successfully');
        Navigator.pop(context, true); // Return to previous screen with refresh signal
      } else {
        _showErrorSnackBar('Failed to start activity');
      }
    } catch (e) {
      _showErrorSnackBar('Error starting activity: $e');
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
      final success = await ExecutionSheetService.stopActivity(
        operationExecutionId: _parcelOperation.operationExecutionId,
        activityId: activity.id,
        jwtToken: widget.jwtToken,
      );

      if (success) {
        _showSuccessSnackBar('Activity stopped successfully');
        Navigator.pop(context, true); // Return to previous screen with refresh signal
      } else {
        _showErrorSnackBar('Failed to stop activity');
      }
    } catch (e) {
      _showErrorSnackBar('Error stopping activity: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildParcelInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _parcelOperation.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text('Operation: ${_parcelOperation.operationExecution?.displayName ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Status: ${_parcelOperation.statusDisplayText}'),
            const SizedBox(height: 4),
            Text('Expected Area: ${_parcelOperation.expectedArea.toStringAsFixed(2)} ha'),
            const SizedBox(height: 4),
            Text('Executed Area: ${_parcelOperation.executedArea.toStringAsFixed(2)} ha'),
            if (_parcelOperation.hasOngoingActivity) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Activity in Progress',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final isMyActivity = activity.operatorId == widget.username;
    final isOngoing = activity.isOngoing;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text('Activity by ${activity.operatorId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Started: ${_formatDateTime(activity.startTime)}'),
            if (activity.endTime != null)
              Text('Ended: ${_formatDateTime(activity.endTime!)}')
            else
              Text(
                'Ongoing',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (activity.duration != null)
              Text('Duration: ${activity.durationText}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyActivity && isOngoing && !_isLoading)
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.red),
                onPressed: () => _stopActivity(activity),
                tooltip: 'Stop Activity',
              ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.primaryGreen),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PoActivityDetailsScreen(
                      activity: activity,
                      jwtToken: widget.jwtToken,
                      canEdit: isMyActivity && !isOngoing,
                    ),
                  ),
                );
              },
              tooltip: 'View Details',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final canStartActivity = _parcelOperation.canStartActivity && !_isLoading;
    final hasOngoingActivity = _parcelOperation.hasOngoingActivity;

    return Scaffold(
      appBar: AppBar(
        title: Text(_parcelOperation.displayName),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          _buildParcelInfo(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_parcelOperation.activities.length} total',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _parcelOperation.activities.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No activities yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start your first activity to begin working on this parcel',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _parcelOperation.activities.length,
                    itemBuilder: (context, index) {
                      return _buildActivityCard(_parcelOperation.activities[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: canStartActivity
          ? FloatingActionButton.extended(
              onPressed: _startActivity,
              backgroundColor: AppColors.primaryGreen,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Starting...' : 'Start Activity'),
            )
          : hasOngoingActivity
              ? FloatingActionButton.extended(
                  onPressed: null,
                  backgroundColor: Colors.grey,
                  icon: const Icon(Icons.pause),
                  label: const Text('Activity in Progress'),
                )
              : null,
    );
  }
}