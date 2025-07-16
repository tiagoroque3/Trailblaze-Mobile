import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/occurrence.dart'; // You will need to create this model
import 'package:trailblaze_app/utils/app_constants.dart';

class ParcelDetailsScreen extends StatefulWidget {
  final ParcelOperationExecution parcel;
  final String jwtToken;

  const ParcelDetailsScreen(
      {super.key, required this.parcel, required this.jwtToken});

  @override
  _ParcelDetailsScreenState createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen> {
  Future<List<Activity>>? _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _fetchActivitiesForParcel();
  }

  Future<List<Activity>> _fetchActivitiesForParcel() async {
    // This endpoint should return activities for a specific parcel within an operation.
    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/operations/${widget.parcel.operationExecutionId}/parcels/${widget.parcel.id}/activities'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Activity.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load activities');
    }
  }

  void _addActivity() {
    // TODO: Implement logic to add a new activity.
    print('Add new activity to parcel ${widget.parcel.id}');
  }

  void _viewOccurrences(String activityId) {
    // TODO: Implement navigation to an occurrences screen.
    print('Viewing occurrences for activity $activityId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parcel ID: ${widget.parcel.id}'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: FutureBuilder<List<Activity>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              color: AppColors.primaryGreen,
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No activities found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final activity = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('Activity by ${activity.operatorId}'),
                    subtitle: Text(
                        'Started: ${activity.startTime.toLocal()}\nEnded: ${activity.endTime?.toLocal() ?? 'Ongoing'}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _viewOccurrences(activity.id),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addActivity,
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add),
      ),
    );
  }
}