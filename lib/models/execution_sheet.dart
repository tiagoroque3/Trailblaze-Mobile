class ExecutionSheet {
  final String id;
  final String title;
  final String state;
  final String associatedWorkSheetId;
  final String associatedUser;
  final double percentExecuted;
  bool isAssignedToCurrentUser; // Add this field

  ExecutionSheet({
    required this.id,
    required this.title,
    required this.state,
    required this.associatedWorkSheetId,
    required this.associatedUser,
    this.percentExecuted = 0.0,
    this.isAssignedToCurrentUser = false, // Initialize to false
  });

  factory ExecutionSheet.fromJson(Map<String, dynamic> json) {
    return ExecutionSheet(
      id: json['id'] ?? '',
      title: json['title'] ?? 'No Title',
      state: json['state'] ?? 'PENDING',
      associatedWorkSheetId: json['associatedWorkSheetId'] ?? '',
      associatedUser: json['associatedUser'] ?? '',
      percentExecuted: (json['percentExecuted'] as num?)?.toDouble() ?? 0.0,
    );
  }
}