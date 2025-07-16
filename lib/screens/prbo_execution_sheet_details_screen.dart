import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/prbo_operation_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class ExecutionSheetDetailsScreen extends StatefulWidget {
  final ExecutionSheet sheet;
  final String jwtToken;

  const ExecutionSheetDetailsScreen(
      {super.key, required this.sheet, required this.jwtToken});

  @override
  _ExecutionSheetDetailsScreenState createState() =>
      _ExecutionSheetDetailsScreenState();
}

class _ExecutionSheetDetailsScreenState
    extends State<ExecutionSheetDetailsScreen> {
  Future<List<OperationExecution>>? _operationsFuture;

  @override
  void initState() {
    super.initState();
    _refreshOperations();
  }

  void _refreshOperations() {
    setState(() {
      _operationsFuture = _fetchOperationsForSheet();
    });
  }

  Future<List<OperationExecution>> _fetchOperationsForSheet() async {
    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/fe/${widget.sheet.id}'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> operationsData = data['operations'] ?? [];
      return operationsData
          .map((json) => OperationExecution.fromJson(json['operationExecution']))
          .toList();
    } else {
      throw Exception(
          'Failed to load operations. Status code: ${response.statusCode}');
    }
  }

  Future<List<ParcelOperationExecution>> _fetchAvailableParcels() async {
    final workSheetId = widget.sheet.associatedWorkSheetId;
    if (workSheetId.isEmpty) return [];

    final response = await http.get(
      Uri.parse(
          'https://trailblaze-460312.appspot.com/rest/fo/$workSheetId/detail'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> parcelsData = data['parcels'] ?? [];
      return parcelsData
          .map((p) => ParcelOperationExecution.fromJson({'parcelId': p['polygon_id'].toString()}))
          .toList();
    } else {
      throw Exception('Failed to load available parcels from worksheet');
    }
  }

  void _showAddOperationDialog() async {
    final formKey = GlobalKey<FormState>();
    final operationIdController = TextEditingController();
    final areaController = TextEditingController();
    String? selectedParcelId;

    // Fetch available parcels for the dropdown
    final List<ParcelOperationExecution> availableParcels = await _fetchAvailableParcels();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Operation to Parcel'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: operationIdController,
                    decoration: const InputDecoration(labelText: 'Operation ID'),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter an Operation ID' : null,
                  ),
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Select Parcel'),
                    items: availableParcels.map((parcel) {
                      return DropdownMenuItem<String>(
                        value: parcel.id,
                        child: Text('Parcel ID: ${parcel.id}'),
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
                    decoration:
                        const InputDecoration(labelText: 'Expected Area (ha)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  _submitAssignment(
                    operationId: operationIdController.text,
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

  Future<void> _submitAssignment(
      {required String operationId,
      required String parcelId,
      required double area}) async {
    final url =
        Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/assign');

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
        _refreshOperations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to assign: ${response.body}'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sheet.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshOperations(),
        child: FutureBuilder<List<OperationExecution>>(
          future: _operationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ));
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text(
                      'No operations found. Use the (+) button to assign one.'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final operation = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text('Operation ID: ${operation.id}'),
                      subtitle: Text('Status: ${operation.state}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OperationDetailsScreen(
                              operation: operation,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOperationDialog,
        backgroundColor: AppColors.primaryGreen,
        tooltip: 'Assign Operation',
        child: const Icon(Icons.add),
      ),
    );
  }
}