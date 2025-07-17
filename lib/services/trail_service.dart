import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/trail.dart';

class TrailService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Criar novo trilho
  static Future<Trail> createTrail({
    required CreateTrailRequest request,
    required String jwtToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trails/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        return Trail.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create trail: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating trail: $e');
    }
  }

  /// Listar todos os trilhos (públicos + próprios)
  static Future<List<Trail>> fetchTrails({
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
        throw Exception('Failed to fetch trails: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching trails: $e');
    }
  }

  /// Obter trilho específico
  static Future<Trail> getTrail({
    required String trailId,
    required String jwtToken,
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
        throw Exception('Failed to get trail: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting trail: $e');
    }
  }

  /// Adicionar observação ao trilho
  static Future<Trail> addObservation({
    required String trailId,
    required String observation,
    required String jwtToken,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trails/update/$trailId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'observation': observation}),
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

  /// Alterar visibilidade do trilho
  static Future<Trail> updateVisibility({
    required String trailId,
    required TrailVisibility visibility,
    required String jwtToken,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trails/$trailId/visibility'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'visibility': visibility.name}),
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

  /// Atualizar status do trilho
  static Future<Trail> updateStatus({
    required String trailId,
    required TrailStatus status,
    required String jwtToken,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trails/$trailId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'status': status.name}),
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

  /// Apagar trilho
  static Future<bool> deleteTrail({
    required String trailId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trails/delete/$trailId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting trail: $e');
    }
  }

  /// Listar trilhos de uma worksheet específica
  static Future<List<Trail>> fetchTrailsByWorksheet({
    required String worksheetId,
    required String jwtToken,
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
        throw Exception('Failed to fetch trails by worksheet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching trails by worksheet: $e');
    }
  }
}