import 'package:trailblaze_app/models/parcel_operation_execution.dart';

class OperationExecution {
  final String id;
  final String name;
  final String executionSheetId;
  final String state;
  final double percentExecuted;
  final double expectedTotalArea;
  final double totalExecutedArea;
  List<ParcelOperationExecution> parcels;

  OperationExecution({
    required this.id,
    required this.name,
    required this.executionSheetId,
    required this.state,
    required this.percentExecuted,
    required this.expectedTotalArea,
    required this.totalExecutedArea,
    this.parcels = const [],
  });

  factory OperationExecution.fromJson(Map<String, dynamic> json) {
    return OperationExecution(
      id: json['id'] ?? '',
      name: 'Operation ${json['operationId'] ?? ''}',
      executionSheetId: json['executionSheetId'] ?? '',
      state: json['state'] ?? 'PENDING',
      percentExecuted: (json['percentExecuted'] as num?)?.toDouble() ?? 0.0,
      expectedTotalArea:
          (json['expectedTotalArea'] as num?)?.toDouble() ?? 0.0,
      totalExecutedArea:
          (json['totalExecutedArea'] as num?)?.toDouble() ?? 0.0,
    );
  }
}