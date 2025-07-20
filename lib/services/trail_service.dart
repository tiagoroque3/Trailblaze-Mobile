import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/trail.dart';

class TrailService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Create a new trail
  static Future<Trail> createTrail({
    required String jwtToken,
    required String name,
    required TrailVisibility visibility,
    required List<TrailPoint> points,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trails/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'name': name,
          'visibility': visibility.name,
          'points': points.map((p) => p.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Trail.fromJson(jsonDecode(response.body));
      } else {
        print('Trail creation failed: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create trail: ${response.body}');
      }
    } catch (e) {
      print('Trail creation error: $e');
      throw Exception('Error creating trail: $e');
    }
  }

  /// Get all trails (public + user's own trails)
  static Future<List<Trail>> getAllTrails({
    required String jwtToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trails/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Trail.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load trails: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching trails: $e');
    }
  }

  /// Get a specific trail by ID
  static Future<Trail> getTrail({
    required String jwtToken,
    required String trailId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trails/get/$trailId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        return Trail.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load trail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching trail: $e');
    }
  }

  /// Add observation to a trail
  static Future<Trail> addObservation({
    required String jwtToken,
    required String trailId,
    required String observation,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trails/update/$trailId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'observation': observation,
        }),
      );

      if (response.statusCode == 200) {
        return Trail.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to add observation: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adding observation: $e');
    }
  }

  /// Update trail visibility
  static Future<Trail> updateVisibility({
    required String jwtToken,
    required String trailId,
    required TrailVisibility visibility,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trails/$trailId/visibility'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'visibility': visibility.name,
        }),
      );

      if (response.statusCode == 200) {
        return Trail.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update visibility: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating visibility: $e');
    }
  }

  /// Update trail status (for private trails only)
  static Future<Trail> updateStatus({
    required String jwtToken,
    required String trailId,
    required TrailStatus status,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trails/$trailId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'status': status.name,
        }),
      );

      if (response.statusCode == 200) {
        return Trail.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating status: $e');
    }
  }

  /// Delete a trail
  static Future<void> deleteTrail({
    required String jwtToken,
    required String trailId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trails/delete/$trailId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete trail: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting trail: $e');
    }
  }

  /// Get trails for a specific worksheet
  static Future<List<Trail>> getTrailsByWorksheet({
    required String jwtToken,
    required String worksheetId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trails/worksheet/$worksheetId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Trail.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load worksheet trails: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching worksheet trails: $e');
    }
  }
}