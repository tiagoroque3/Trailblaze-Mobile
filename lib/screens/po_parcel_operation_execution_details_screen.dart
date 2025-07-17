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
    return Scaffold(
      appBar: AppBar(
        title: Text('Parcel: ${widget.parcelOperation.parcelId}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.parcelOperation.activities.length,
              itemBuilder: (context, index) {
                final activity = widget.parcelOperation.activities[index];
                final isMyActivity = activity.operatorId == widget.username;

                // Show only activities for the current user
                if (!isMyActivity) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('Activity by ${activity.operatorId}'),
                    subtitle: Text(
                        'Started: ${activity.startTime.toLocal()}\nEnded: ${activity.endTime?.toLocal() ?? 'Ongoing'}'),
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
    );
  }
}