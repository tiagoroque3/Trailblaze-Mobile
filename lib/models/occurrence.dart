// lib/models/occurrence.dart
import 'package:flutter/material.dart';

class Occurrence {
  final String id;
  final String incidentType;
  final String description;
  final List<String> evidenceUrls;
  final String state; // OccurrenceState enum as String
  final DateTime creationTime;
  final String createdBy;
  final String executionSheetId;
  final DateTime? resolutionTime;
  final String? resolvedBy;

  Occurrence({
    required this.id,
    required this.incidentType,
    required this.description,
    this.evidenceUrls = const [],
    required this.state,
    required this.creationTime,
    required this.createdBy,
    required this.executionSheetId,
    this.resolutionTime,
    this.resolvedBy,
  });

  factory Occurrence.fromJson(Map<String, dynamic> json) {
    return Occurrence(
      id: json['id'] as String,
      incidentType: json['incidentType'] as String,
      description: json['description'] as String,
      evidenceUrls: (json['evidenceUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      state: json['state'] as String,
      creationTime: DateTime.fromMillisecondsSinceEpoch(json['creationTime'] as int),
      createdBy: json['createdBy'] as String,
      executionSheetId: json['executionSheetId'] as String,
      resolutionTime: json['resolutionTime'] != null && json['resolutionTime'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(json['resolutionTime'] as int)
          : null,
      resolvedBy: json['resolvedBy'] as String?,
    );
  }
}