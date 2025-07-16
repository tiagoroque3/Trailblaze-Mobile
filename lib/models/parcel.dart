// lib/models/parcel.dart
class Parcel {
  final String id;
  final String name;
  final String description;
  final List<List<double>> coordinates; // Lista de coordenadas [lat, lng] para formar o polígono
  final String? color; // Cor opcional para o polígono

  Parcel({
    required this.id,
    required this.name,
    required this.description,
    required this.coordinates,
    this.color,
  });

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coordinates: (json['coordinates'] as List<dynamic>)
          .map((coord) => (coord as List<dynamic>)
              .map((c) => (c as num).toDouble())
              .toList())
          .toList(),
      color: json['color'] as String?,
    );
  }

  factory Parcel.fromWorksheetJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['polygonId']?.toString() ?? '',
      name: 'Parcel ${json['polygonId']?.toString() ?? ''}',
      description: '',
      coordinates: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coordinates': coordinates,
      'color': color,
    };
  }
}