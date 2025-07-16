import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/prbo_parcel_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class OperationDetailsScreen extends StatefulWidget {
  final OperationExecution operation;
  final String jwtToken;

  const OperationDetailsScreen(
      {super.key, required this.operation, required this.jwtToken});

  @override
  _OperationDetailsScreenState createState() => _OperationDetailsScreenState();
}

class _OperationDetailsScreenState extends State<OperationDetailsScreen> {
  Future<List<ParcelOperationExecution>>? _parcelsFuture;

  @override
  void initState() {
    super.initState();
    _parcelsFuture = _fetchParcelsForOperation();
  }

  Future<List<ParcelOperationExecution>> _fetchParcelsForOperation() async {
    // This endpoint should return parcels for a specific operation.
    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/operations/${widget.operation.id}/parcels'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ParcelOperationExecution.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load parcels');
    }
  }

  void _addParcel() {
    // TODO: Implement the logic to show a dialog and add a new parcel.
    print('Add new parcel to operation ${widget.operation.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Operation: ${widget.operation.name}'),
        backgroundColor: AppColors.primaryGreen,
      ),
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
            return const Center(child: Text('No parcels found.'));
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
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ParcelDetailsScreen(
                            parcel: parcel,
                            jwtToken: widget.jwtToken,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addParcel,
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add),
      ),
    );
  }
}