class ExecutionSheet {
  final String id;
  final String title;
  final String state;
  final String associatedWorkSheetId;
  final String associatedUser;
  final double percentExecuted; // Assuming this might be part of the data

  ExecutionSheet({
    required this.id,
    required this.title,
    required this.state,
    required this.associatedWorkSheetId,
    required this.associatedUser,
    this.percentExecuted = 0.0,
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