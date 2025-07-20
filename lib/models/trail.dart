import 'dart:convert';
import 'dart:math';
enum TrailVisibility { PRIVATE, PUBLIC }

enum TrailStatus { ACTIVE, COMPLETED, PAUSED }

class TrailPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;

  TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
  });

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      altitude: json['altitude'] != null ? (json['altitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (altitude != null) 'altitude': altitude,
    };
  }

  bool get isValid {
    return latitude >= -90 && latitude <= 90 && 
           longitude >= -180 && longitude <= 180;
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

class Trail {
  final String id;
  final String name;
  final String createdBy;
  final String? worksheetId;
  final TrailVisibility visibility;
  final TrailStatus? status;
  final DateTime createdAt;
  final List<TrailPoint> points;
  final List<TrailObservation> observations;

  Trail({
    required this.id,
    required this.name,
    required this.createdBy,
    this.worksheetId,
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
      worksheetId: json['worksheetId'] as String?,
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
          .toList() ?? [],
      observations: (json['observations'] as List<dynamic>?)
          ?.map((o) => TrailObservation.fromJson(o as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // Helper method to handle different timestamp formats from backend
  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdBy': createdBy,
      if (worksheetId != null) 'worksheetId': worksheetId,
      'visibility': visibility.name,
      if (status != null) 'status': status!.name,
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

  String get formattedDistance {
    if (points.length < 2) return '0.0 km';
    
    double totalDistance = 0.0;
    for (int i = 1; i < points.length; i++) {
      totalDistance += _calculateDistance(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    
    return '${totalDistance.toStringAsFixed(2)} km';
  }

  Duration get duration {
    if (points.isEmpty) return Duration.zero;
    if (points.length == 1) return Duration.zero;
    
    return points.last.timestamp.difference(points.first.timestamp);
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

double _calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371.0; // em km

  // converte graus para radianos
  double toRad(double degree) => degree * pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(toRad(lat1)) * cos(toRad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}
}