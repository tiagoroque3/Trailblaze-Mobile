import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/services/prbo_execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PrboAssignParcelScreen extends StatefulWidget {
  final ExecutionSheet executionSheet;
  final String jwtToken;
  final String username;
  final List<String>? assignedParcelIds; // IDs das parcelas já atribuídas

  const PrboAssignParcelScreen({
    super.key,
    required this.executionSheet,
    required this.jwtToken,
    required this.username,
    this.assignedParcelIds,
  });

  @override
  State<PrboAssignParcelScreen> createState() => _PrboAssignParcelScreenState();
}

class _PrboAssignParcelScreenState extends State<PrboAssignParcelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _assignedUsernameController = TextEditingController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _operations = [];
  List<Map<String, dynamic>> _parcels = [];

  String? _selectedOperationId;
  String? _selectedParcelId;
  bool _operationsLoading = true;
  bool _parcelsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  @override
  void dispose() {
    _areaController.dispose();
    _assignedUsernameController.dispose();
    super.dispose();
  }

  Future<void> _loadOperations() async {
    setState(() {
      _operationsLoading = true;
    });

    try {
      final sheetDetails =
          await PrboExecutionService.fetchExecutionSheetDetails(
            sheetId: widget.executionSheet.id,
            jwtToken: widget.jwtToken,
          );

      final operations = sheetDetails['operations'] as List<dynamic>? ?? [];

      setState(() {
        _operations = operations.map((op) {
          final opExec = op['operationExecution'];
          return {
            'operationId': opExec['operationId'],
            'executionId': opExec['id'],
            'displayName': 'Operation ${opExec['operationId']}',
          };
        }).toList();
        _operationsLoading = false;
      });
    } catch (e) {
      setState(() {
        _operationsLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading operations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadParcelsForOperation(String operationId) async {
    setState(() {
      _parcelsLoading = true;
      _parcels.clear();
      _selectedParcelId = null;
    });

    try {
      final parcels = await PrboExecutionService.fetchParcelsForWorksheet(
        worksheetId: widget.executionSheet.associatedWorkSheetId,
        jwtToken: widget.jwtToken,
      );

      // Filtrar parcelas já atribuídas
      List<Map<String, dynamic>> availableParcels = parcels;
      if (widget.assignedParcelIds != null &&
          widget.assignedParcelIds!.isNotEmpty) {
        availableParcels = parcels.where((parcel) {
          final parcelId =
              parcel['id']?.toString() ?? parcel['parcelId']?.toString();
          return parcelId != null &&
              !widget.assignedParcelIds!.contains(parcelId);
        }).toList();
      }

      setState(() {
        _parcels = availableParcels;
        _parcelsLoading = false;
      });
    } catch (e) {
      setState(() {
        _parcelsLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parcels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignParcel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedOperationId == null || _selectedParcelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both operation and parcel'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await PrboExecutionService.assignOperationToParcels(
        jwtToken: widget.jwtToken,
        executionSheetId: widget.executionSheet.id,
        operationId: _selectedOperationId!,
        parcelExecutions: [
          {
            'parcelId': _selectedParcelId!,
            'area': double.parse(_areaController.text),
            'assignedUsername': _assignedUsernameController.text.trim(),
          },
        ],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcel assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning parcel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Parcel to Operation'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Execution Sheet Info Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Execution Sheet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('Title: ${widget.executionSheet.title}'),
                      const SizedBox(height: 4),
                      Text('ID: ${widget.executionSheet.id}'),
                      const SizedBox(height: 4),
                      Text(
                        'Worksheet ID: ${widget.executionSheet.associatedWorkSheetId}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Operation Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Operation *',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_operationsLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        )
                      else if (_operations.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No operations found for this execution sheet',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedOperationId,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: 'Select an operation',
                            prefixIcon: const Icon(Icons.work_outline),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: _operations.map((operation) {
                            return DropdownMenuItem<String>(
                              value: operation['operationId'],
                              child: Text(
                                operation['displayName'] ?? 'Unknown Operation',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedOperationId = value;
                              _selectedParcelId = null;
                            });
                            if (value != null) {
                              _loadParcelsForOperation(value);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select an operation';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select an existing operation from this execution sheet',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Parcel Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Parcel *',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_parcelsLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        )
                      else if (_selectedOperationId == null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Select an operation first',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_parcels.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_outlined,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.assignedParcelIds != null &&
                                          widget.assignedParcelIds!.isNotEmpty
                                      ? 'No unassigned parcels available in this worksheet'
                                      : 'No parcels available in this worksheet',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedParcelId,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: 'Select a parcel',
                            prefixIcon: const Icon(Icons.landscape_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: _parcels.map((parcel) {
                            final parcelId =
                                parcel['id']?.toString() ??
                                parcel['parcelId']?.toString() ??
                                'Unknown';
                            final aigp = parcel['aigp']?.toString() ?? 'N/A';
                            final ruralPropertyId =
                                parcel['ruralPropertyId']?.toString() ?? 'N/A';

                            return DropdownMenuItem<String>(
                              value: parcelId,
                              child: Text(
                                'Parcel $parcelId - $aigp ($ruralPropertyId)',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedParcelId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a parcel';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 8),
                      Text(
                        widget.assignedParcelIds != null &&
                                widget.assignedParcelIds!.isNotEmpty
                            ? 'Select an unassigned parcel from the worksheet'
                            : 'Select an existing parcel from the worksheet',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (widget.assignedParcelIds != null &&
                          widget.assignedParcelIds!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${widget.assignedParcelIds!.length} parcel(s) already assigned',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Area Input
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected Area (ha) *',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _areaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: 'Enter expected area in hectares',
                          suffixText: 'ha',
                          prefixIcon: const Icon(Icons.square_foot_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the expected area';
                          }
                          final area = double.tryParse(value);
                          if (area == null || area <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Assigned Username Input
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Username *',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _assignedUsernameController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText:
                              'Enter username to assign this parcel operation',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the username to assign this parcel operation';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _assignParcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Assign Parcel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
