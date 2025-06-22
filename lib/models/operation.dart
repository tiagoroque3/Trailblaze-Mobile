// lib/models/operation.dart
class Operation {
  final String id;
  final String executionSheetId;
  final String name;
  final String parcelId;
  final String assignedOperator;
  final String state; // OperationState enum as String

  Operation({
    required this.id,
    required this.executionSheetId,
    required this.name,
    required this.parcelId,
    required this.assignedOperator,
    required this.state,
  });

  factory Operation.fromJson(Map<String, dynamic> json) {
    return Operation(
      id: json['id'] as String,
      executionSheetId: json['executionSheetId'] as String,
      name: json['name'] as String,
      parcelId: json['parcelId'] as String,
      assignedOperator: json['assignedOperator'] as String,
      state: json['state'] as String,
    );
  }
}