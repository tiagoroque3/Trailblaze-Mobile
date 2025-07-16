import 'package:trailblaze_app/models/parcel_operation_execution.dart';

class OperationExecution {
  final String id;
  final String executionSheetId;
  final String operationId;
  final String? operationCode;
  final String? operationDescription;
  final DateTime? startDate;
  final DateTime? lastActivityDate;
  final DateTime? completionDate;
  final double totalExecutedArea;
  final double percentExecuted;
  final double expectedTotalArea;
  final DateTime? predictedEndDate;
  final int? estimatedDurationMinutes;
  final String? observations;
  final List<String> parcelOperationExecutionIds;
  List<ParcelOperationExecution> parcels;

  OperationExecution({
    required this.id,
    required this.executionSheetId,
    required this.operationId,
    this.operationCode,
    this.operationDescription,
    this.startDate,
    this.lastActivityDate,
    this.completionDate,
    this.totalExecutedArea = 0.0,
    this.percentExecuted = 0.0,
    this.expectedTotalArea = 0.0,
    this.predictedEndDate,
    this.estimatedDurationMinutes,
    this.observations,
    this.parcelOperationExecutionIds = const [],
    this.parcels = const [],
  });

  factory OperationExecution.fromJson(Map<String, dynamic> json) {
    return OperationExecution(
      id: json['id'] ?? '',
      executionSheetId: json['executionSheetId'] ?? '',
      operationId: json['operationId'] ?? '',
      operationCode: json['operationCode'],
      operationDescription: json['description'],
      startDate: json['startDate'] != null 
          ? DateTime.parse(json['startDate']) 
          : null,
      lastActivityDate: json['lastActivityDate'] != null 
          ? DateTime.parse(json['lastActivityDate']) 
          : null,
      completionDate: json['completionDate'] != null 
          ? DateTime.parse(json['completionDate']) 
          : null,
      totalExecutedArea: (json['totalExecutedArea'] as num?)?.toDouble() ?? 0.0,
      percentExecuted: (json['percentExecuted'] as num?)?.toDouble() ?? 0.0,
      expectedTotalArea: (json['expectedTotalArea'] as num?)?.toDouble() ?? 0.0,
      predictedEndDate: json['predictedEndDate'] != null 
          ? DateTime.parse(json['predictedEndDate']) 
          : null,
      estimatedDurationMinutes: json['estimatedDurationMinutes'],
      observations: json['observations'],
      parcelOperationExecutionIds: List<String>.from(
          json['parcelOperationExecutionIds'] ?? []),
    );
  }

  String get displayName => operationCode != null 
      ? 'Operation $operationCode' 
      : 'Operation $operationId';

  bool get isStarted => startDate != null;
  bool get isCompleted => completionDate != null;
  bool get isInProgress => isStarted && !isCompleted;

  String get statusText {
    if (isCompleted) return 'Completed';
    if (isInProgress) return 'In Progress';
    return 'Pending';
  }
}