import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/screens/po_parcel_activity_screen.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoExecutionSheetDetailsScreen extends StatefulWidget {
  final ExecutionSheet sheet;
  final String jwtToken;
  final String username;

  const PoExecutionSheetDetailsScreen({
    Key? key,
    required this.sheet,
    required this.jwtToken,
    required this.username,
  }) : super(key: key);

  @override
  _PoExecutionSheetDetailsScreenState createState() =>
      _PoExecutionSheetDetailsScreenState();
}

class _PoExecutionSheetDetailsScreenState
    extends State<PoExecutionSheetDetailsScreen> {
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
      final data = await ExecutionService.fetchExecutionSheetDetails(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Execution Sheet Details')),
      body: FutureBuilder<List<ParcelOperationExecution>>(
        future: _parcelOperationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final assignedParcels = snapshot.data!
              .where(
                (parcel) => parcel.activities.any(
                  (a) => a.operatorId == widget.username,
                ),
              )
              .toList();

          if (assignedParcels.isEmpty) {
            return _buildEmptyState();
          }

          return _buildParcelOperationsList(assignedParcels);
        },
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
            'No assigned operations',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any assigned activities in this execution sheet',
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
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: parcels.length,
      itemBuilder: (context, index) {
        return _buildParcelOperationCard(parcels[index]);
      },
    );
  }

  Widget _buildParcelOperationCard(ParcelOperationExecution parcelOp) {
    final myActivities = parcelOp.activities
        .where((activity) => activity.operatorId == widget.username)
        .toList();

    final Activity? ongoingActivity =
        myActivities
            .where((a) => a.endTime == null)
            .cast<Activity?>()
            .isNotEmpty
        ? myActivities.firstWhere((a) => a.endTime == null)
        : null;

    final completedCount = myActivities.where((a) => a.endTime != null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PoParcelActivityScreen(
                parcelOperation: parcelOp,
                jwtToken: widget.jwtToken,
                username: widget.username,
              ),
            ),
          ).then((_) => _refreshData());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parcel ${parcelOp.parcelId}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parcelOp.operationExecution?.name ??
                              'Unknown Operation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(parcelOp.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildActivitySummaryItem(
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    value: completedCount.toString(),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  if (ongoingActivity != null)
                    _buildActivitySummaryItem(
                      icon: Icons.play_circle_outline,
                      label: 'Ongoing',
                      value: '1',
                      color: Colors.blue,
                    ),
                ],
              ),
              const SizedBox(height: 12),
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

  Widget _buildStatusChip(String status) {
    late final Color backgroundColor;
    late final Color textColor;

    switch (status.toUpperCase()) {
      case 'ASSIGNED':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'EXECUTED':
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

  Widget _buildActivitySummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
