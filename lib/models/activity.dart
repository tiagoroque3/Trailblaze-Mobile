class Activity {
  final String id;
  final String parcelOperationExecutionId;
  final String operatorId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? observations;
  final String? gpsTrack;
  final List<String> photoUrls;

  Activity({
    required this.id,
    required this.parcelOperationExecutionId,
    required this.operatorId,
    required this.startTime,
    this.endTime,
    this.observations,
    this.gpsTrack,
    this.photoUrls = const [],
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['activityId'] ?? json['id'] ?? '',
      parcelOperationExecutionId: json['parcelOperationExecutionId'] ?? '',
      operatorId: json['operatorId'] ?? '',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : DateTime.now(),
      endTime: json['endTime'] != null && json['endTime'].toString().isNotEmpty
          ? DateTime.parse(json['endTime'])
          : null,
      observations: json['observations'],
      gpsTrack: json['gpsTrack'],
      photoUrls: List<String>.from(json['photoUrls'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activityId': id,
      'parcelOperationExecutionId': parcelOperationExecutionId,
      'operatorId': operatorId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'observations': observations,
      'gpsTrack': gpsTrack,
      'photoUrls': photoUrls,
    };
  }

  bool get isOngoing => endTime == null;
  bool get isCompleted => endTime != null;

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  String get durationText {
    final dur = duration;
    if (dur == null) return 'Ongoing';
    
    final hours = dur.inHours;
    final minutes = dur.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get statusText => isOngoing ? 'Ongoing' : 'Completed';
}