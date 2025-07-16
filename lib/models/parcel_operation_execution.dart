import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/operation_execution.dart';

enum ParcelExecutionStatus {
  PENDING,
  ASSIGNED,
  IN_PROGRESS,
  EXECUTED,
  COMPLETED
}

class ParcelOperationExecution {
  final String id;
  final String operationExecutionId;
  final String parcelId;
  final ParcelExecutionStatus status;
  final DateTime? startDate;
  final DateTime? lastActivityDate;
  final DateTime? completionDate;
  final double expectedArea;
  final double executedArea;
  final String? assignedOperatorId;
  final List<String> activityIds;
  OperationExecution? operationExecution;
  List<Activity> activities;

  ParcelOperationExecution({
    required this.id,
    required this.operationExecutionId,
    required this.parcelId,
    required this.status,
    this.startDate,
    this.lastActivityDate,
    this.completionDate,
    this.expectedArea = 0.0,
    this.executedArea = 0.0,
    this.assignedOperatorId,
    this.activityIds = const [],
    this.operationExecution,
    this.activities = const [],
  });

  factory ParcelOperationExecution.fromJson(Map<String, dynamic> json) {
    return ParcelOperationExecution(
      id: json['id'] ?? '',
      operationExecutionId: json['operationExecutionId'] ?? '',
      parcelId: json['parcelId'] ?? '',
      status: ParcelExecutionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ParcelExecutionStatus.PENDING,
      ),
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate']) 
          : null,
      lastActivityDate: json['lastActivityDate'] != null 
          ? DateTime.parse(json['lastActivityDate']) 
          : null,
      completionDate: json['completionDate'] != null 
          ? DateTime.parse(json['completionDate']) 
          : null,
      expectedArea: (json['expectedArea'] as num?)?.toDouble() ?? 0.0,
      executedArea: (json['executedArea'] as num?)?.toDouble() ?? 0.0,
      assignedOperatorId: json['assignedOperatorId'],
      activityIds: List<String>.from(json['activityIds'] ?? []),
    );
  }

  bool get isAssignedToUser => assignedOperatorId != null;
  bool get hasOngoingActivity => activities.any((a) => a.endTime == null);
  bool get canStartActivity => status == ParcelExecutionStatus.ASSIGNED && !hasOngoingActivity;
  
  Activity? get currentActivity => activities.firstWhere(
    (a) => a.endTime == null,
    orElse: () => null as dynamic,
  );

  String get statusDisplayText {
    switch (status) {
      case ParcelExecutionStatus.PENDING:
        return 'Pending';
      case ParcelExecutionStatus.ASSIGNED:
        return 'Assigned';
      case ParcelExecutionStatus.IN_PROGRESS:
        return 'In Progress';
      case ParcelExecutionStatus.EXECUTED:
        return 'Executed';
      case ParcelExecutionStatus.COMPLETED:
        return 'Completed';
    }
  }

  String get displayName => 'Parcel $parcelId';
}