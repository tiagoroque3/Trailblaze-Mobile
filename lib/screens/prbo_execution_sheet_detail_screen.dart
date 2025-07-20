import 'package:flutter/material.dart';

import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/prbo_parcel_activity_screen.dart';
import 'package:trailblaze_app/screens/prbo_assign_parcel_screen.dart';
import 'package:trailblaze_app/services/prbo_execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PrboExecutionSheetDetailsScreen extends StatefulWidget {
  final ExecutionSheet sheet;
  final String jwtToken;
  final String username;

  const PrboExecutionSheetDetailsScreen({
    Key? key,
    required this.sheet,
    required this.jwtToken,
    required this.username,
  }) : super(key: key);

  @override
  _PrboExecutionSheetDetailsScreenState createState() =>
      _PrboExecutionSheetDetailsScreenState();
}

class _PrboExecutionSheetDetailsScreenState
    extends State<PrboExecutionSheetDetailsScreen> {
  late Future<List<ParcelOperationExecution>> _parcelOperationsFuture;

  @override
  void initState() {
    super.initState();
    _parcelOperationsFuture = _fetchExecutionSheetData();
  }

  void _refreshData() {
    setState(() {
      _parcelOperationsFuture = _fetchExecutionSheetData();
    });
  }

  Future<List<ParcelOperationExecution>> _fetchExecutionSheetData() async {
    try {
      final data = await PrboExecutionService.fetchExecutionSheetDetails(
        sheetId: widget.sheet.id,
        jwtToken: widget.jwtToken,
      );

      final operationsData = data['operations'] ?? [];
      List<ParcelOperationExecution> parcelOperations = [];

      for (var opData in operationsData) {
        OperationExecution opExec = OperationExecution.fromJson(
          opData['operationExecution'],
        );
        final parcelsData = opData['parcels'] ?? [];

        for (var parcelData in parcelsData) {
          ParcelOperationExecution parcelOp = ParcelOperationExecution.fromJson(
            parcelData['parcelExecution'],
          );
          parcelOp.operationExecution = opExec;
          parcelOp.activities = (parcelData['activities'] as List<dynamic>)
              .map((activityJson) => Activity.fromJson(activityJson))
              .toList();

          parcelOperations.add(parcelOp);
        }
      }

      return parcelOperations;
    } catch (e) {
      throw Exception('Failed to load execution sheet data: $e');
    }
  }

  void _navigateToAssignParcel() async {
    // Coletar IDs das parcelas já atribuídas
    List<String> assignedParcelIds = [];

    try {
      final data = await PrboExecutionService.fetchExecutionSheetDetails(
        sheetId: widget.sheet.id,
        jwtToken: widget.jwtToken,
      );

      final operationsData = data['operations'] ?? [];
      for (var opData in operationsData) {
        final parcelsData = opData['parcels'] ?? [];
        for (var parcelData in parcelsData) {
          final parcelExecution = parcelData['parcelExecution'];
          final parcelId = parcelExecution['parcelId']?.toString();
          if (parcelId != null && !assignedParcelIds.contains(parcelId)) {
            assignedParcelIds.add(parcelId);
          }
        }
      }
    } catch (e) {
      // Se houver erro ao carregar, continua sem filtrar
      print('Error loading assigned parcels: $e');
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PrboAssignParcelScreen(
          executionSheet: widget.sheet,
          jwtToken: widget.jwtToken,
          username: widget.username,
          assignedParcelIds: assignedParcelIds,
        ),
      ),
    );

    // If the assignment was successful, refresh the data
    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sheet.title),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Execution Sheet Info Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.sheet.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        _buildStatusChip(widget.sheet.state),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Work Sheet ID:',
                      widget.sheet.associatedWorkSheetId,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Associated User:',
                      widget.sheet.associatedUser,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Sheet ID:', widget.sheet.id),
                  ],
                ),
              ),
            ),
          ),

          // Operations List
          Expanded(
            child: FutureBuilder<List<ParcelOperationExecution>>(
              future: _parcelOperationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading operations',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final parcels = snapshot.data ?? [];

                if (parcels.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildParcelOperationsList(parcels);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAssignParcel,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        label: const Text('Assign Parcel'),
        icon: const Icon(Icons.add_task),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PENDING':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'COMPLETED':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No parcels found',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'This execution sheet doesn\'t have any assigned parcels yet',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelOperationsList(List<ParcelOperationExecution> parcels) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: parcels.length,
        itemBuilder: (context, index) {
          return _buildParcelOperationCard(parcels[index]);
        },
      ),
    );
  }

  Widget _buildParcelOperationCard(ParcelOperationExecution parcel) {
    final operation = parcel.operationExecution;
    final activities = parcel.activities;

    // Calculate activity statistics
    int totalActivities = activities.length;
    int completedActivities = activities.where((a) => a.endTime != null).length;
    int ongoingActivities = activities.where((a) => a.endTime == null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrboParcelActivityScreen(
                parcelOperationExecution: parcel,
                jwtToken: widget.jwtToken,
                username: widget.username,
              ),
            ),
          ).then((_) => _refreshData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with operation info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operation ${operation?.id ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Parcel ${parcel.parcelId}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (parcel.assignedUsername != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Assigned PO: ${parcel.assignedUsername}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildOperationStatusChip(
                    parcel.id,
                  ), // Use parcel ID as status for now
                ],
              ),

              const SizedBox(height: 12),

              // Activity summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(
                          'Total',
                          totalActivities.toString(),
                          Colors.blue,
                        ),
                        _buildStatColumn(
                          'Ongoing',
                          ongoingActivities.toString(),
                          Colors.orange,
                        ),
                        _buildStatColumn(
                          'Completed',
                          completedActivities.toString(),
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Action row
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to manage activities',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Active',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
