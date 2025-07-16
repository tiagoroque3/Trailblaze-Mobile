import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/execution_sheet.dart';
import '../models/operation_execution.dart';
import '../models/parcel_operation_execution.dart';
import '../models/activity.dart';

class ExecutionSheetService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Fetch execution sheets for PO (filtered by user assignments)
  static Future<List<ExecutionSheet>> fetchExecutionSheets({
    required String jwtToken,
    String? statusFilter,
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
        return data.map((json) => ExecutionSheet.fromJson(json)).toList();
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
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Parse execution sheet
        final executionSheet = ExecutionSheet.fromJson(data['executionSheet']);
        
        // Parse operations with their parcels
        final List<dynamic> operationsData = data['operations'] ?? [];
        List<OperationExecution> operations = [];
        
        for (var opData in operationsData) {
          final operation = OperationExecution.fromJson(opData['operationExecution']);
          
          // Parse parcels for this operation
          final List<dynamic> parcelsData = opData['parcels'] ?? [];
          List<ParcelOperationExecution> parcels = [];
          
          for (var parcelData in parcelsData) {
            final parcel = ParcelOperationExecution.fromJson(parcelData['parcelExecution']);
            parcel.operationExecution = operation;
            
            // Parse activities for this parcel
            final List<dynamic> activitiesData = parcelData['activities'] ?? [];
            parcel.activities = activitiesData
                .map((activityJson) => Activity.fromJson(activityJson))
                .toList();
            
            parcels.add(parcel);
          }
          
          operation.parcels = parcels;
          operations.add(operation);
        }
        
        return {
          'executionSheet': executionSheet,
          'operations': operations,
        };
      } else {
        throw Exception('Failed to load execution sheet details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching execution sheet details: $e');
    }
  }

  /// Start a new activity for a parcel operation
  static Future<bool> startActivity({
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

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error starting activity: $e');
      return false;
    }
  }

  /// Stop an ongoing activity
  static Future<bool> stopActivity({
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

      return response.statusCode == 200;
    } catch (e) {
      print('Error stopping activity: $e');
      return false;
    }
  }

  /// Add additional information to a completed activity
  static Future<bool> addActivityInfo({
    required String activityId,
    String? observations,
    List<String>? gpsTracks,
    List<String>? photos,
    required String jwtToken,
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
          'gpsTracks': gpsTracks,
          'photos': photos,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding activity info: $e');
      return false;
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