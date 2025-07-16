class Event {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final String location;
  final String workSheetId;
  final String createdBy;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.location,
    required this.workSheetId,
    required this.createdBy,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dateTime'] as int),
      location: json['location'] as String,
      workSheetId: json['workSheetId'] as String,
      createdBy: json['createdBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'location': location,
      'workSheetId': workSheetId,
      'createdBy': createdBy,
    };
  }

  String get formattedDateTime {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedLocation {
    try {
      final parts = location.split(',');
      if (parts.length == 2) {
        final lat = double.parse(parts[0]).toStringAsFixed(4);
        final lng = double.parse(parts[1]).toStringAsFixed(4);
        return '$lat, $lng';
      }
    } catch (e) {
      // If parsing fails, return original location
    }
    return location;
  }
}