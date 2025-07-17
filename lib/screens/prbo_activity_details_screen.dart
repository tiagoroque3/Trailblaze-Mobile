import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/services/prbo_execution_service.dart';
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
  final _observationsController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.activity.observations != null) {
      _observationsController.text = widget.activity.observations!;
    }
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _addObservation() async {
    final observation = _observationsController.text.trim();
    if (observation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an observation'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await PrboExecutionService.addActivityInfo(
        activityId: widget.activity.id,
        jwtToken: widget.jwtToken,
        observations: observation,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observation added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the parent screen to show updated data
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add observation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addPhoto() async {
    // This is a placeholder for photo upload functionality
    // You would implement actual photo selection and upload here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Photo'),
        content: const Text('Photo upload functionality will be implemented here.\n\nThis would typically include:\n• Camera capture\n• Gallery selection\n• Upload to server\n• Update activity record'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addGpsTrack() async {
    // This is a placeholder for GPS tracking functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add GPS Track'),
        content: const Text('GPS tracking functionality will be implemented here.\n\nThis would typically include:\n• Current location capture\n• Track recording\n• Upload to server\n• Update activity record'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        actions: [
          if (widget.canEdit)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'photo':
                    _addPhoto();
                    break;
                  case 'gps':
                    _addGpsTrack();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'photo',
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt, size: 20),
                      SizedBox(width: 8),
                      Text('Add Photo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'gps',
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 20),
                      SizedBox(width: 8),
                      Text('Add GPS Track'),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
                    _buildDetailRow('Start Time:', formatDateTime(widget.activity.startTime)),
                    const Divider(),
                    _buildDetailRow('End Time:', formatDateTime(widget.activity.endTime)),
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
                              Icon(Icons.photo_library, size: 32, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Photos will be displayed here', style: TextStyle(color: Colors.grey)),
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

            // Observations Section
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
                    const Text(
                      'Observations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.canEdit) ...[
                      TextFormField(
                        controller: _observationsController,
                        decoration: const InputDecoration(
                          labelText: 'Add or edit observations',
                          hintText: 'Enter your observations here...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addObservation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save Observations'),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          widget.activity.observations?.isNotEmpty == true
                              ? widget.activity.observations!
                              : 'No observations recorded',
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.activity.observations?.isNotEmpty == true
                                ? Colors.black87
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
                          title: const Text('Add Photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _addPhoto();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.location_on, color: AppColors.primaryGreen),
                          title: const Text('Add GPS Track'),
                          onTap: () {
                            Navigator.pop(context);
                            _addGpsTrack();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.comment, color: AppColors.primaryGreen),
                          title: const Text('Add Observation'),
                          onTap: () {
                            Navigator.pop(context);
                            // Focus on the observations text field
                            FocusScope.of(context).requestFocus(FocusNode());
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Info'),
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            )
          : null,
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