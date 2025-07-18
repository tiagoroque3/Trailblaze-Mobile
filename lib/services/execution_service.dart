import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:proj4dart/proj4dart.dart' as proj4;
import '../models/execution_sheet.dart';
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
        List<ExecutionSheet> sheets =
            data.map((json) => ExecutionSheet.fromJson(json)).toList();

        if (onlyAssigned) {
          // Filter will be applied after checking assignments in the UI layer
          return sheets;
        }

        return sheets;
      } else {
        throw Exception(
            'Failed to load execution sheets: ${response.statusCode}');
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
        throw Exception(
            'Failed to load execution sheet details: ${response.statusCode}');
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

  /// NEW METHOD: Fetch parcel geometry for the live tracking map
  static Future<List<LatLng>> fetchParcelGeometry({
    required String jwtToken,
    required String worksheetId,
    required String parcelId,
  }) async {
    // CORRECTED ENDPOINT: Directly fetches a specific parcel's geometry
    final Uri url = Uri.parse('$baseUrl/fo/$worksheetId/parcels/$parcelId'); // Changed this line
    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $jwtToken',
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> parcelJson = jsonDecode(response.body);

        // Check if the geometry field exists in the response
        if (parcelJson.containsKey('geometry')) {
          return _convertGeometryToLatLng(parcelJson['geometry']);
        } else {
          throw Exception('Geometry data not found in the response for parcel $parcelId');
        }
      } else {
        throw Exception(
          'Failed to fetch parcel details for worksheet $worksheetId and parcel $parcelId. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching parcel geometry: $e');
    }
  }

  /// NEW HELPER METHOD: Converts geometry coordinates to LatLng points
  static List<LatLng> _convertGeometryToLatLng(
      Map<String, dynamic>? geometry) {
    if (geometry == null || geometry['coordinates'] == null) {
      return [];
    }

    // Define the source and destination projections
    final proj4.Projection portugueseProjection = proj4.Projection.add(
        'EPSG:3763',
        '+proj=tmerc +lat_0=39.66825833333333 +lon_0=-8.133108333333334 '
        '+k=1 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs');
    final proj4.Projection wgs84Projection = proj4.Projection.get('EPSG:4326')!;

    List<List<dynamic>> rings =
        List<List<dynamic>>.from(geometry['coordinates']);
    List<LatLng> latLngPoints = [];

    if (rings.isNotEmpty) {
      // A polygon is defined by rings, we use the first (exterior) ring
      List<dynamic> exteriorRing = rings[0];
      for (var coord in exteriorRing) {
        if (coord is List && coord.length >= 2) {
          var point =
              proj4.Point(x: coord[0].toDouble(), y: coord[1].toDouble());
          // Transform the point from the Portuguese projection to WGS84 (used by Google Maps)
          var wgs84Point =
              portugueseProjection.transform(wgs84Projection, point);
          latLngPoints.add(LatLng(wgs84Point.y, wgs84Point.x));
        }
      }
    }
    return latLngPoints;
  }
}
