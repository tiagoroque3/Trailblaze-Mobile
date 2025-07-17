class TrailPoint {
  final double latitude;
  final double longitude;

  TrailPoint({
    required this.latitude,
    required this.longitude,
  });

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  bool isValid() {
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }
}

class TrailObservation {
  final String username;
  final String observation;
  final DateTime timestamp;

  TrailObservation({
    required this.username,
    required this.observation,
    required this.timestamp,
  });

  factory TrailObservation.fromJson(Map<String, dynamic> json) {
    return TrailObservation(
      username: json['username'] as String,
      observation: json['observation'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'observation': observation,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

enum TrailVisibility {
  PUBLIC,
  PRIVATE,
}

enum TrailStatus {
  ACTIVE,
  COMPLETED,
}

class Trail {
  final String id;
  final String name;
  final String createdBy;
  final String worksheetId;
  final TrailVisibility visibility;
  final TrailStatus? status;
  final DateTime createdAt;
  final List<TrailPoint> points;
  final List<TrailObservation> observations;

  Trail({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.worksheetId,
    required this.visibility,
    this.status,
    required this.createdAt,
    required this.points,
    required this.observations,
  });

  factory Trail.fromJson(Map<String, dynamic> json) {
    return Trail(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] as String,
      worksheetId: json['worksheetId'] as String,
      visibility: TrailVisibility.values.firstWhere(
        (e) => e.name == json['visibility'],
        orElse: () => TrailVisibility.PRIVATE,
      ),
      status: json['status'] != null
          ? TrailStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => TrailStatus.ACTIVE,
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => TrailPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      observations: (json['observations'] as List<dynamic>?)
              ?.map((o) => TrailObservation.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'worksheetId': worksheetId,
      'visibility': visibility.name,
      'status': status?.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'points': points.map((p) => p.toJson()).toList(),
      'observations': observations.map((o) => o.toJson()).toList(),
    };
  }

  bool canBeViewedBy(String username) {
    return createdBy == username || visibility == TrailVisibility.PUBLIC;
  }

  bool canBeEditedBy(String username) {
    return createdBy == username || visibility == TrailVisibility.PUBLIC;
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get statusText {
    if (visibility == TrailVisibility.PUBLIC) return 'Public';
    return status?.name ?? 'Active';
  }

  double get totalDistance {
    if (points.length < 2) return 0.0;
    
    double total = 0.0;
    for (int i = 1; i < points.length; i++) {
      total += _calculateDistance(points[i - 1], points[i]);
    }
    return total;
  }

  double _calculateDistance(TrailPoint p1, TrailPoint p2) {
    const double earthRadius = 6371000; // metros
    
    double lat1Rad = p1.latitude * (3.14159 / 180);
    double lat2Rad = p2.latitude * (3.14159 / 180);
    double deltaLatRad = (p2.latitude - p1.latitude) * (3.14159 / 180);
    double deltaLngRad = (p2.longitude - p1.longitude) * (3.14159 / 180);

    double a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLngRad / 2).sin() * (deltaLngRad / 2).sin();
    double c = 2 * (a.sqrt()).atan2((1 - a).sqrt());

    return earthRadius * c;
  }
}

class CreateTrailRequest {
  final String name;
  final String worksheetId;
  final TrailVisibility visibility;
  final List<TrailPoint> points;

  CreateTrailRequest({
    required this.name,
    required this.worksheetId,
    required this.visibility,
    required this.points,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'worksheetId': worksheetId,
      'visibility': visibility.name,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  bool isValid() {
    return name.trim().isNotEmpty && worksheetId.trim().isNotEmpty;
  }
}