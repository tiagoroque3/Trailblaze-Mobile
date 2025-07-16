import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/po_parcel_operation_execution_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/models/activity.dart';

class PoExecutionSheetDetailsScreen extends StatefulWidget {
  final ExecutionSheet sheet;
  final String jwtToken;
  final String username;

  const PoExecutionSheetDetailsScreen({
    super.key,
    required this.sheet,
    required this.jwtToken,
    required this.username,
  });

  @override
  _PoExecutionSheetDetailsScreenState createState() =>
      _PoExecutionSheetDetailsScreenState();
}

class _PoExecutionSheetDetailsScreenState
    extends State<PoExecutionSheetDetailsScreen> {
  Future<List<ParcelOperationExecution>>? _parcelOperationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _parcelOperationsFuture = _fetchParcelOperations();
    });
  }

  Future<List<ParcelOperationExecution>> _fetchParcelOperations() async {
    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/fe/${widget.sheet.id}'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> operationsData = data['operations'] ?? [];

      List<ParcelOperationExecution> parcelOperations = [];
      for (var opData in operationsData) {
        OperationExecution opExec =
            OperationExecution.fromJson(opData['operationExecution']);
        List<dynamic> parcelsData = opData['parcels'] ?? [];
        for (var parcelData in parcelsData) {
          ParcelOperationExecution parcelOp =
              ParcelOperationExecution.fromJson(parcelData['parcelExecution']);
          parcelOp.operationExecution = opExec;
          parcelOp.activities = (parcelData['activities'] as List<dynamic>)
              .map((activityJson) => Activity.fromJson(activityJson))
              .toList();
          parcelOperations.add(parcelOp);
        }
      }
      return parcelOperations;
    } else {
      throw Exception(
          'Failed to load data. Status code: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sheet.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: FutureBuilder<List<ParcelOperationExecution>>(
          future: _parcelOperationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryGreen,
                ),
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('No parcel operations found for this sheet.'),
              );
            } else {
              // Filter to show only parcels where the PO is the operator of at least one activity
              final assignedParcels = snapshot.data!.where((parcelOp) {
                return parcelOp.activities.any((activity) => activity.operatorId == widget.username);
              }).toList();

              if (assignedParcels.isEmpty) {
                return const Center(child: Text('You have no assigned operations in this sheet.'));
              }

              return ListView.builder(
                itemCount: assignedParcels.length,
                itemBuilder: (context, index) {
                  final parcelOp = assignedParcels[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(
                          'Parcel ID: ${parcelOp.parcelId} - Operation: ${parcelOp.operationExecution?.name ?? 'N/A'}'),
                      subtitle: Text('Status: ${parcelOp.status}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PoParcelOperationExecutionDetailsScreen(
                              parcelOperation: parcelOp,
                              jwtToken: widget.jwtToken,
                              username: widget.username,
                            ),
                          ),
                        ).then((_) => _refreshData());
                      },
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}