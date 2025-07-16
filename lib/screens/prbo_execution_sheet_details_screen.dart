import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/models/parcel.dart';
import 'package:trailblaze_app/screens/prbo_parcel_operation_execution_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/models/activity.dart';

class ExecutionSheetDetailsScreen extends StatefulWidget {
  final ExecutionSheet sheet;
  final String jwtToken;
  final String username;

  const ExecutionSheetDetailsScreen({
    super.key,
    required this.sheet,
    required this.jwtToken,
    required this.username,
  });

  @override
  _ExecutionSheetDetailsScreenState createState() =>
      _ExecutionSheetDetailsScreenState();
}

class _ExecutionSheetDetailsScreenState
    extends State<ExecutionSheetDetailsScreen> {
  Future<List<dynamic>>? _dataFuture;
  List<OperationExecution> _existingOperations = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _dataFuture = _fetchExecutionSheetData();
    });
    await _dataFuture;
  }

  Future<List<dynamic>> _fetchExecutionSheetData() async {
    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/fe/${widget.sheet.id}'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> operationsData = data['operations'] ?? [];

      List<ParcelOperationExecution> parcelOperations = [];
      List<OperationExecution> existingOps = [];

      for (var opData in operationsData) {
        OperationExecution opExec =
            OperationExecution.fromJson(opData['operationExecution']);
        existingOps.add(opExec); // Store the operation

        List<dynamic> parcelsData = opData['parcels'] ?? [];
        if (parcelsData.isEmpty) {
          // Add operations that have no parcels yet, so they appear in the list
          parcelOperations.add(ParcelOperationExecution(
            id: 'op-only-${opExec.id}', // A temporary unique ID for the list
            operationExecutionId: opExec.id,
            parcelId: 'No parcels assigned',
            status: 'PENDING',
            operationExecution: opExec
          ));
        } else {
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
      }
      
      // Update the state with the list of operations for the dialog
      _existingOperations = existingOps;
      
      return parcelOperations;
    } else {
      throw Exception(
          'Failed to load data. Status code: ${response.statusCode}');
    }
  }
  
  Future<List<Parcel>> _fetchAvailableParcels() async {
     final workSheetId = widget.sheet.associatedWorkSheetId;
    if (workSheetId.isEmpty) {
      throw Exception('Associated WorkSheet ID is missing.');
    }

    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/fo/$workSheetId/detail'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> parcelsData = data['parcels'] ?? [];
      return parcelsData.map((p) => Parcel.fromWorksheetJson(p)).toList();
    } else {
      throw Exception('Failed to load available parcels from worksheet');
    }
  }


  void _addParcelOperation() async {
    // Check if there are any operations on this sheet to assign to.
    if (_existingOperations.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No operations available on this sheet to assign parcels to.'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final availableParcels = await _fetchAvailableParcels();
      _showAddOperationDialog(availableParcels, _existingOperations);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddOperationDialog(List<Parcel> parcels, List<OperationExecution> operations) {
    final formKey = GlobalKey<FormState>();
    final areaController = TextEditingController();
    String? selectedParcelId;
    String? selectedOperationId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Parcel to Operation'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Operation'),
                    items: operations.map((op) {
                      return DropdownMenuItem<String>(
                        value: op.id, // This is the OperationExecution ID
                        // Displaying the operation name (which includes its original ID from worksheet)
                        child: Text(op.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis,),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedOperationId = value;
                    },
                    validator: (value) =>
                        value == null ? 'Please select an operation' : null,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Parcel'),
                    items: parcels.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id, // This is the parcel's ID
                        child: Text('Parcel ID: ${p.id}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      selectedParcelId = value;
                    },
                    validator: (value) =>
                        value == null ? 'Please select a parcel' : null,
                  ),
                  TextFormField(
                    controller: areaController,
                    decoration: const InputDecoration(labelText: 'Expected Area (ha)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter an area' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final selectedOp = operations.firstWhere((op) => op.id == selectedOperationId);
                  
                  _submitAssignment(
                    operationId: selectedOp.id,
                    parcelId: selectedParcelId!,
                    area: double.tryParse(areaController.text) ?? 0.0,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAssignment({required String operationId, required String parcelId, required double area}) async {
    final url = Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/assign');

    final body = jsonEncode({
      'executionSheetId': widget.sheet.id,
      'operationId': operationId,
      'parcelExecutions': [
        {'parcelId': parcelId, 'area': area}
      ]
    });

    try {
      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.jwtToken}'
          },
          body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Operation assigned successfully!'),
              backgroundColor: Colors.green),
        );
        _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to assign: ${response.body} (Code: ${response.statusCode})'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canAdd = widget.sheet.associatedUser == widget.username;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sheet.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<dynamic>>(
          future: _dataFuture,
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
                child: Text(
                    'No operations or parcels found. Use the (+) button to assign a parcel (must be assigned to you).'),
              );
            } else {
              final items = snapshot.data as List<ParcelOperationExecution>;
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  bool isOperationOnly = item.parcelId == 'No parcels assigned';

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(
                          isOperationOnly 
                          ? 'Operation: ${item.operationExecution?.name ?? 'N/A'}'
                          : 'Parcel ID: ${item.parcelId}'
                      ),
                      subtitle: Text(
                        isOperationOnly
                        ? 'No parcels assigned yet.'
                        : 'Operation: ${item.operationExecution?.name ?? 'N/A'} | Status: ${item.status}'
                      ),
                      trailing: isOperationOnly ? null : const Icon(Icons.arrow_forward_ios),
                      onTap: isOperationOnly ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ParcelOperationExecutionDetailsScreen(
                              parcelOperation: item,
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
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: _addParcelOperation,
              backgroundColor: AppColors.primaryGreen,
              tooltip: 'Add Parcel to Operation',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}