import 'dart:convert';

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
      photoUrls: _parsePhotoUrls(json['photoUrls']),
    );
  }

  /// Parse and clean photo URLs that might be mixed formats
  static List<String> _parsePhotoUrls(dynamic photoUrlsData) {
    if (photoUrlsData == null) return [];

    List<String> cleanUrls = [];
    List<dynamic> rawUrls = List.from(photoUrlsData);

    for (var urlData in rawUrls) {
      if (urlData is String) {
        // Check if it's a JSON string
        if (urlData.trim().startsWith('{') && urlData.trim().endsWith('}')) {
          try {
            // Parse JSON and extract photoUrl
            var jsonMap = jsonDecode(urlData);
            if (jsonMap['photoUrl'] != null) {
              cleanUrls.add(jsonMap['photoUrl'].toString());
            }
          } catch (e) {
            // If parsing fails, treat as regular URL
            cleanUrls.add(urlData);
          }
        } else {
          // Regular URL string
          cleanUrls.add(urlData);
        }
      }
    }

    return cleanUrls;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parcelOperationExecutionId': parcelOperationExecutionId,
      'operatorId': operatorId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'observations': observations,
      'photoUrls': photoUrls,
    };
  }
}
