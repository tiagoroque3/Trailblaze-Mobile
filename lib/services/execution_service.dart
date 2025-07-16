import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/execution_sheet.dart';
import '../models/operation_execution.dart';
import '../models/parcel_operation_execution.dart';
import '../models/activity.dart';

class ExecutionService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Fetch execution sheets for PO role
  static Future<List<ExecutionSheet>> fetchExecutionSheets({
    required String jwtToken,
    String? statusFilter,
    bool onlyAssigned = false,
  }) async {
    try {
      String url = '$baseUrl/fe';
      if (statusFilter != null && statusFilter.isNotEmpty) {
        url += '/status/$statusFilter';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<ExecutionSheet> sheets = data.map((json) => ExecutionSheet.fromJson(json)).toList();
        
        if (onlyAssigned) {
          // Filter will be applied after checking assignments in the UI layer
          return sheets;
        }
        
        return sheets;
      } else {
        throw Exception('Failed to load execution sheets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching execution sheets: $e');
    }
  }

  /// Fetch detailed execution sheet with operations and parcels
  static Future<Map<String, dynamic>> fetchExecutionSheetDetails({
    required String sheetId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fe/$sheetId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load execution sheet details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching execution sheet details: $e');
    }
  }

  /// Start a new activity for a parcel operation
  static Future<Map<String, dynamic>> startActivity({
    required String operationExecutionId,
    required String parcelOperationExecutionId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/operations/$operationExecutionId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'parcelOperationExecutionId': parcelOperationExecutionId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to start activity: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error starting activity: $e');
    }
  }

  /// Stop an ongoing activity
  static Future<Map<String, dynamic>> stopActivity({
    required String operationExecutionId,
    required String activityId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/operations/$operationExecutionId/stop'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'activityId': activityId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to stop activity: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error stopping activity: $e');
    }
  }

  /// Add information to a completed activity
  static Future<bool> addActivityInfo({
    required String activityId,
    required String jwtToken,
    String? observations,
    List<String>? photoUrls,
    List<String>? gpsTracks,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/operations/activity/addinfo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'activityId': activityId,
          'observations': observations,
          'photos': photoUrls,
          'gpsTracks': gpsTracks,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error adding activity info: $e');
    }
  }

  /// Fetch activities for a specific operation
  static Future<List<Activity>> fetchActivitiesForOperation({
    required String operationExecutionId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/operations/$operationExecutionId/activities'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Activity.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load activities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching activities: $e');
    }
  }
}