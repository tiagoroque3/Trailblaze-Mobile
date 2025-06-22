class CreateOccurrenceRequest {
  final String incidentType;
  final String description;
  final List<String>? evidenceUrls;

  CreateOccurrenceRequest({
    required this.incidentType,
    required this.description,
    this.evidenceUrls,
  });

  Map<String, dynamic> toJson() {
    return {
      'incidentType': incidentType,
      'description': description,
      'evidenceUrls': evidenceUrls ?? [],
    };
  }
}