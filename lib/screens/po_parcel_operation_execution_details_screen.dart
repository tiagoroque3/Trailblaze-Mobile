import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
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
  State<PoParcelOperationExecutionDetailsScreen> createState() => _PoParcelOperationExecutionDetailsScreenState();
}

class _PoParcelOperationExecutionDetailsScreenState extends State<PoParcelOperationExecutionDetailsScreen> {
  
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _startActivity() async {
    final url = Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/${widget.parcelOperation.operationExecutionId}/start');
    final body = jsonEncode({'parcelOperationExecutionId': widget.parcelOperation.id});

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwtToken}'
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Activity started successfully.');
        // The parent screen will refresh when we pop back.
        Navigator.of(context).pop(true);
      } else {
        _showSnackBar('Failed to start activity: ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e', isError: true);
    }
  }

  Future<void> _stopActivity(String activityId) async {
    final url = Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/${widget.parcelOperation.operationExecutionId}/stop');
    final body = jsonEncode({'activityId': activityId});

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwtToken}'
        },
        body: body,
      );

      if (response.statusCode == 200) {
        _showSnackBar('Activity stopped successfully.');
        Navigator.of(context).pop(true);
      } else {
        _showSnackBar('Failed to stop activity: ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ongoingActivity = widget.parcelOperation.activities.firstWhere(
      (act) => act.endTime == null && act.operatorId == widget.username,
      orElse: () => null as dynamic,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Parcel: ${widget.parcelOperation.parcelId}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.parcelOperation.activities.length,
              itemBuilder: (context, index) {
                final activity = widget.parcelOperation.activities[index];
                final isOngoing = activity.endTime == null;
                final isMyActivity = activity.operatorId == widget.username;

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('Activity by ${activity.operatorId}'),
                    subtitle: Text(
                        'Started: ${activity.startTime.toLocal()}\nEnded: ${activity.endTime?.toLocal() ?? 'Ongoing'}'),
                    trailing: (isMyActivity && isOngoing)
                        ? ElevatedButton(
                            onPressed: () => _stopActivity(activity.id),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Stop'),
                          )
                        : null,
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Show start button only if there are no ongoing activities for this user on this parcel
      floatingActionButton: ongoingActivity == null
          ? FloatingActionButton.extended(
              onPressed: _startActivity,
              label: const Text('Start New Activity'),
              icon: const Icon(Icons.play_arrow),
              backgroundColor: AppColors.primaryGreen,
            )
          : null,
    );
  }
}