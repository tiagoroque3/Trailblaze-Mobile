import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/widgets/photo_gallery_widget.dart';

class PoActivityManagementScreen extends StatefulWidget {
  final Activity activity;
  final String jwtToken;
  final bool isOngoing;

  const PoActivityManagementScreen({
    super.key,
    required this.activity,
    required this.jwtToken,
    required this.isOngoing,
  });

  @override
  State<PoActivityManagementScreen> createState() =>
      _PoActivityManagementScreenState();
}

class _PoActivityManagementScreenState
    extends State<PoActivityManagementScreen> {
  final TextEditingController _observationsController = TextEditingController();
  bool _isLoading = false;
  List<String> _photoUrls = [];

  @override
  void initState() {
    super.initState();
    _observationsController.text = widget.activity.observations ?? '';
    _photoUrls = List.from(widget.activity.photoUrls);
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _stopActivity() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First stop the activity
      await ExecutionService.stopActivity(
        operationExecutionId: widget
            .activity
            .parcelOperationExecutionId, // This might need adjustment based on your data structure
        activityId: widget.activity.id,
        jwtToken: widget.jwtToken,
      );

      // Then add any observations or photos if provided
      if (_observationsController.text.isNotEmpty || _photoUrls.isNotEmpty) {
        await _saveActivityInfo();
      }

      _showSnackBar('Activity stopped successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to stop activity: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveActivityInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ExecutionService.addActivityInfo(
        activityId: widget.activity.id,
        jwtToken: widget.jwtToken,
        observations: _observationsController.text.isNotEmpty
            ? _observationsController.text
            : null,
        photoUrls: _photoUrls.isNotEmpty ? _photoUrls : null,
      );

      if (success) {
        _showSnackBar('Activity information saved successfully');
        if (!widget.isOngoing) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showSnackBar('Failed to save activity information', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error saving activity information: $e', isError: true);
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
    final duration = widget.isOngoing
        ? DateTime.now().difference(widget.activity.startTime)
        : widget.activity.endTime!.difference(widget.activity.startTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOngoing ? 'Ongoing Activity' : 'Activity Details'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (widget.isOngoing)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              onPressed: _isLoading ? null : _stopActivity,
              tooltip: 'Stop Activity',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),

                          _buildInfoRow(
                            'Date',
                            DateFormat(
                              'MMM dd, yyyy',
                            ).format(widget.activity.startTime),
                            Icons.calendar_today,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoRow(
                            'Start Time',
                            DateFormat(
                              'HH:mm',
                            ).format(widget.activity.startTime),
                            Icons.play_arrow,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoRow(
                            'End Time',
                            widget.isOngoing
                                ? 'Ongoing'
                                : DateFormat(
                                    'HH:mm',
                                  ).format(widget.activity.endTime!),
                            widget.isOngoing ? Icons.timer : Icons.stop,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoRow(
                            'Duration',
                            _formatDuration(duration),
                            Icons.timer_outlined,
                          ),
                          const SizedBox(height: 8),

                          _buildInfoRow(
                            'Status',
                            widget.isOngoing ? 'In Progress' : 'Completed',
                            widget.isOngoing
                                ? Icons.play_circle
                                : Icons.check_circle,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Observations section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Observations',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _observationsController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText:
                                  'Add your observations about this activity...',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            enabled: !_isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Photos section using our new widget
                  PhotoGalleryWidget(
                    photoUrls: _photoUrls,
                    jwtToken: widget.jwtToken,
                    activityId: widget.activity.id,
                    canEdit: true,
                    onPhotosUpdated: (updatedPhotos) {
                      setState(() {
                        _photoUrls = updatedPhotos;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  if (!widget.isOngoing) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveActivityInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _stopActivity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Stop Activity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
