// lib/models/activity.dart
class Activity {
  final String id;
  final String operationId;
  final String operatorId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? observations;
  final List<String> photos;
  final List<String> gpsTracks;

  Activity({
    required this.id,
    required this.operationId,
    required this.operatorId,
    required this.startTime,
    this.endTime,
    this.observations,
    this.photos = const [],
    this.gpsTracks = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      operationId: json['operationId'] as String,
      operatorId: json['operatorId'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: json['endTime'] != null && json['endTime'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int)
          : null,
      observations: json['observations'] as String?,
      // Corrected parsing: expect a List<dynamic> and map to List<String>
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      // Corrected parsing: expect a List<dynamic> and map to List<String>
      gpsTracks: (json['gpsTracks'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  // toJson method is kept for completeness, no changes needed here for now.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationId': operationId,
      'operatorId': operatorId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch ?? 0,
      'observations': observations,
      'photos': photos,
      'gpsTracks': gpsTracks,
    };
  }
}