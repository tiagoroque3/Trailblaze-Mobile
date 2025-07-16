class ParcelOperationExecution {
  final String id;
  final String operationExecutionId;
  final String parcelId;
  final String status;
  final String? assignedOperatorId;

  ParcelOperationExecution({
    required this.id,
    required this.operationExecutionId,
    required this.parcelId,
    required this.status,
    this.assignedOperatorId,
  });

  factory ParcelOperationExecution.fromJson(Map<String, dynamic> json) {
     // The 'json' passed here is the 'parcelExecution' object from the response
    return ParcelOperationExecution(
      id: json['id'] ?? '',
      operationExecutionId: json['operationExecutionId'] ?? '',
      parcelId: json['parcelId'] ?? '',
      status: json['status'] ?? 'PENDING',
      assignedOperatorId: json['assignedOperatorId'],
    );
  }
}