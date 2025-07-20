class ExecutionSheet {
  final String id;
  final String title;
  final String? description; // Added description field
  final String state;
  final String associatedWorkSheetId;
  final String associatedUser;
  final double percentExecuted;
  final DateTime? startDate;
  final DateTime? lastActivity;
  bool isAssignedToCurrentUser; // Add this field

  ExecutionSheet({
    required this.id,
    required this.title,
    this.description, // Added description parameter
    required this.state,
    required this.associatedWorkSheetId,
    required this.associatedUser,
    this.percentExecuted = 0.0,
    this.startDate,
    this.lastActivity,
    this.isAssignedToCurrentUser = false, // Initialize to false
  });

  factory ExecutionSheet.fromJson(Map<String, dynamic> json) {
    return ExecutionSheet(
      id: json['id'] ?? '',
      title: json['title'] ?? 'No Title',
      description: json['description'], // Added description parsing
      state: json['state'] ?? 'PENDING',
      associatedWorkSheetId: json['associatedWorkSheetId'] ?? '',
      associatedUser: json['associatedUser'] ?? '',
      percentExecuted: (json['percentExecuted'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startDate'])
          : null,
      lastActivity: json['lastActivity'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActivity'])
          : null,
    );
  }
}
