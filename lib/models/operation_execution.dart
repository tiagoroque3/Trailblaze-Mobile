import 'package:trailblaze_app/models/parcel_operation_execution.dart';

class OperationExecution {
  final String id;
  final String name;
  final String executionSheetId;
  final String state;
  final double percentExecuted;
  final double expectedTotalArea;
  final double totalExecutedArea;
  final DateTime? startDate;
  final DateTime? lastActivity;
  List<ParcelOperationExecution> parcels;

  OperationExecution({
    required this.id,
    required this.name,
    required this.executionSheetId,
    required this.state,
    required this.percentExecuted,
    required this.expectedTotalArea,
    required this.totalExecutedArea,
    this.startDate,
    this.lastActivity,
    this.parcels = const [],
  });

  factory OperationExecution.fromJson(Map<String, dynamic> json) {
    return OperationExecution(
      id: json['id'] ?? '',
      name: 'Operation ${json['operationId'] ?? json['id'] ?? ''}',
      executionSheetId: json['executionSheetId'] ?? '',
      state: json['state'] ?? 'PENDING',
      percentExecuted: (json['percentExecuted'] as num?)?.toDouble() ?? 0.0,
      expectedTotalArea: (json['expectedTotalArea'] as num?)?.toDouble() ?? 0.0,
      totalExecutedArea: (json['totalExecutedArea'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startDate'])
          : null,
      lastActivity: json['lastActivity'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActivity'])
          : null,
    );
  }
}
