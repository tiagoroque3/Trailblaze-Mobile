import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/operation_execution.dart';

class ParcelOperationExecution {
  final String id;
  final String operationExecutionId;
  final String parcelId;
  final String status;
  final String? assignedOperatorId;
  final String?
  assignedUsername; // Username do PO assigned a esta ParcelOperationExecution
  final double? expectedArea;
  OperationExecution? operationExecution;
  List<Activity> activities;

  ParcelOperationExecution({
    required this.id,
    required this.operationExecutionId,
    required this.parcelId,
    required this.status,
    this.assignedOperatorId,
    this.assignedUsername,
    this.expectedArea,
    this.operationExecution,
    this.activities = const [],
  });

  factory ParcelOperationExecution.fromJson(Map<String, dynamic> json) {
    return ParcelOperationExecution(
      id: json['id'] ?? '',
      operationExecutionId: json['operationExecutionId'] ?? '',
      parcelId: json['parcelId'] ?? '',
      status: json['status'] ?? 'PENDING',
      assignedOperatorId: json['assignedOperatorId'],
      assignedUsername: json['assignedUsername'],
      expectedArea: (json['expectedArea'] as num?)?.toDouble(),
    );
  }
}
