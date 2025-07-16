class Activity {
  final String id;
  final String parcelOperationExecutionId;
  final String operatorId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? observations;
  final List<String> photoUrls;

  Activity({
    required this.id,
    required this.parcelOperationExecutionId,
    required this.operatorId,
    required this.startTime,
    this.endTime,
    this.observations,
    this.photoUrls = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? '',
      parcelOperationExecutionId: json['parcelOperationExecutionId'] ?? '',
      operatorId: json['operatorId'] ?? '',
      startTime: json['startTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startTime'])
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'])
          : null,
      observations: json['observations'],
      photoUrls: List<String>.from(json['photoUrls'] ?? []),
    );
  }
}