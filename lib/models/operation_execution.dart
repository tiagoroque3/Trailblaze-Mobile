class OperationExecution {
  final String id;
  final String name;
  final String executionSheetId;
  final String state;
  final double percentExecuted;
  final double expectedTotalArea;
  final double totalExecutedArea;

  OperationExecution({
    required this.id,
    required this.name,
    required this.executionSheetId,
    required this.state,
    required this.percentExecuted,
    required this.expectedTotalArea,
    required this.totalExecutedArea,
  });

  factory OperationExecution.fromJson(Map<String, dynamic> json) {
    // The 'json' passed here is the 'operationExecution' object from the response
    return OperationExecution(
      id: json['id'] ?? '',
      // Assuming 'operationId' from the backend corresponds to 'name' or 'id' for display
      name: 'Operation ${json['operationId'] ?? ''}', 
      executionSheetId: json['executionSheetId'] ?? '',
      // The backend doesn't seem to have a 'state' field in OperationExecution
      // I'll keep it for now, but you might need to adjust based on your actual JSON
      state: json['state'] ?? 'PENDING', 
      percentExecuted: (json['percentExecuted'] as num?)?.toDouble() ?? 0.0,
      expectedTotalArea: (json['expectedTotalArea'] as num?)?.toDouble() ?? 0.0,
      totalExecutedArea: (json['totalExecutedArea'] as num?)?.toDouble() ?? 0.0,
    );
  }
}