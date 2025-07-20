import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/execution_sheet.dart';
import '../models/activity.dart';

class PrboExecutionService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Fetch all execution sheets (PRBO has access to all)
  static Future<List<ExecutionSheet>> fetchAllExecutionSheets({
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
        throw Exception(
          'Failed to load execution sheets: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching execution sheets: $e');
    }
  }

  /// Fetch execution sheets by specific user (admin feature)
  static Future<List<ExecutionSheet>> fetchExecutionSheetsByUser({
    required String jwtToken,
    required String targetUsername,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fe/user/$targetUsername'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ExecutionSheet.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load execution sheets for user: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching execution sheets for user: $e');
    }
  }

  /// Fetch available worksheets (for creating new execution sheets)
  static Future<List<Map<String, dynamic>>> fetchAvailableWorksheets({
    required String jwtToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fe/available-worksheets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Failed to load available worksheets: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching available worksheets: $e');
    }
  }

  /// Create a new execution sheet
  static Future<ExecutionSheet> createExecutionSheet({
    required String jwtToken,
    required String title,
    required String associatedWorkSheetId,
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fe/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'title': title,
          'associatedWorkSheetId': associatedWorkSheetId,
          'description': description,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ExecutionSheet.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create execution sheet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating execution sheet: $e');
    }
  }

  /// Update an existing execution sheet
  static Future<ExecutionSheet> updateExecutionSheet({
    required String jwtToken,
    required String sheetId,
    String? title,
    String? associatedUser,
    String? description,
    String? state,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (title != null) updateData['title'] = title;
      // Note: associatedWorkSheetId is not editable after creation
      if (associatedUser != null) updateData['associatedUser'] = associatedUser;
      if (description != null) updateData['description'] = description;
      if (state != null) updateData['state'] = state;

      final response = await http.put(
        Uri.parse('$baseUrl/fe/$sheetId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        return ExecutionSheet.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update execution sheet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating execution sheet: $e');
    }
  }

  /// Delete an execution sheet
  static Future<void> deleteExecutionSheet({
    required String jwtToken,
    required String sheetId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/fe/$sheetId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete execution sheet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting execution sheet: $e');
    }
  }

  /// Export execution sheet
  static Future<Map<String, dynamic>> exportExecutionSheet({
    required String jwtToken,
    required String sheetId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fe/export/$sheetId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to export execution sheet: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error exporting execution sheet: $e');
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
        throw Exception(
          'Failed to load execution sheet details: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching execution sheet details: $e');
    }
  }

  /// Assign operations to parcels
  static Future<Map<String, dynamic>> assignOperationToParcels({
    required String jwtToken,
    required String executionSheetId,
    required String operationId,
    required List<Map<String, dynamic>> parcelExecutions,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/operations/assign'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'executionSheetId': executionSheetId,
          'operationId': operationId,
          'parcelExecutions': parcelExecutions,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Failed to assign operation to parcels: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error assigning operation to parcels: $e');
    }
  }

  /// Fetch parcels for a worksheet (used for assign operation)
  static Future<List<Map<String, dynamic>>> fetchParcelsForWorksheet({
    required String worksheetId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fo/$worksheetId/parcels'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Failed to load parcels for worksheet: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching parcels for worksheet: $e');
    }
  }

  /// Edit operation execution
  static Future<Map<String, dynamic>> editOperationExecution({
    required String jwtToken,
    required String operationExecutionId,
    Map<String, dynamic>? updateData,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/operations/edit-operation-execution'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'operationExecutionId': operationExecutionId,
          ...?updateData,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to edit operation execution: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error editing operation execution: $e');
    }
  }

  /// List parcels for operation
  static Future<List<Map<String, dynamic>>> listParcelsForOperation({
    required String jwtToken,
    required String operationExecutionId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/operations/$operationExecutionId/parcels'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
          'Failed to load parcels for operation: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching parcels for operation: $e');
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
        body: jsonEncode({'activityId': activityId}),
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

  /// Fetch activities for a specific operation parcel
  static Future<List<Activity>> fetchActivitiesForOperationParcel({
    required String operationExecutionId,
    required String parcelOperationExecutionId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/operations/$operationExecutionId/parcels/$parcelOperationExecutionId/activities',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Activity.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load activities for parcel: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching activities for parcel: $e');
    }
  }
}
