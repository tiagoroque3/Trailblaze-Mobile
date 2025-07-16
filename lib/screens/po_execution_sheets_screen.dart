import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoExecutionSheetsView extends StatefulWidget {
  final String jwtToken;
  final String username;

  const PoExecutionSheetsView(
      {super.key, required this.jwtToken, required this.username});

  @override
  _PoExecutionSheetsViewState createState() => _PoExecutionSheetsViewState();
}

class _PoExecutionSheetsViewState extends State<PoExecutionSheetsView> {
  Future<List<ParcelOperationExecution>>? _parcelsFuture;

  @override
  void initState() {
    super.initState();
    _parcelsFuture = _fetchAssignedParcels();
  }

  Future<List<ParcelOperationExecution>> _fetchAssignedParcels() async {
    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/users/${widget.username}/parcels'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ParcelOperationExecution.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load assigned parcels');
    }
  }

  void _startActivity(String operationId, String parcelId) {
    // TODO: Implement start activity logic
    print('Starting activity for parcel $parcelId in operation $operationId');
  }

  void _stopActivity(String operationId, String parcelId) {
    // TODO: Implement stop activity logic
    print('Stopping activity for parcel $parcelId in operation $operationId');
  }

  void _addInfo(String parcelId) {
    // TODO: Implement add info logic (photos, observations, GPS)
    print('Adding info for parcel $parcelId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<ParcelOperationExecution>>(
        future: _parcelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
              color: AppColors.primaryGreen,
            ));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No assigned parcels found.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final parcel = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text('Parcel ID: ${parcel.id}'),
                    subtitle: Text('Status: ${parcel.status}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () =>
                              _startActivity(parcel.operationExecutionId, parcel.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: () =>
                              _stopActivity(parcel.operationExecutionId, parcel.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_a_photo),
                          onPressed: () => _addInfo(parcel.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}