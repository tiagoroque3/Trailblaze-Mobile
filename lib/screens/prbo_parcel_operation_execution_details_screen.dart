import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/prbo_activity_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class ParcelOperationExecutionDetailsScreen extends StatelessWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String username;

  const ParcelOperationExecutionDetailsScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parcel: ${parcelOperation.parcelId} - Op: ${parcelOperation.operationExecution?.name}',
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: ListView.builder(
        itemCount: parcelOperation.activities.length,
        itemBuilder: (context, index) {
          final activity = parcelOperation.activities[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text('Activity by ${activity.operatorId}'),
              subtitle: Text(
                'Started: ${activity.startTime.toLocal()}\nEnded: ${activity.endTime?.toLocal() ?? 'Ongoing'}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrboActivityDetailsScreen(
                      activity: activity,
                      jwtToken: jwtToken,
                      username: username,
                      canEdit: true, // PRBO can edit activities
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
