import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/event.dart';

class EventService {
  static const String baseUrl = 'https://trailblaze-460312.appspot.com/rest';

  /// Fetch all events (requires authentication)
  static Future<List<Event>> fetchAllEvents({String? jwtToken}) async {
    try {
      final Uri url = Uri.parse('$baseUrl/events');
      
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      
      if (jwtToken != null) {
        headers['Authorization'] = 'Bearer $jwtToken';
      }

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> eventsJson = jsonDecode(response.body);
        return eventsJson.map((json) => Event.fromJson(json)).toList();
      } else {
        print('Error fetching events: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  /// Fetch events the user is registered for (RU only)
  static Future<List<Event>> fetchMyEvents({required String jwtToken}) async {
    try {
      final Uri url = Uri.parse('$baseUrl/events/registered');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> eventsJson = jsonDecode(response.body);
        return eventsJson.map((json) => Event.fromJson(json)).toList();
      } else {
        print('Error fetching my events: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching my events: $e');
      return [];
    }
  }

  /// Register for an event (RU only)
  static Future<bool> registerForEvent({
    required String eventId,
    required String jwtToken,
  }) async {
    try {
      final Uri url = Uri.parse('$baseUrl/events/$eventId/register');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error registering for event: $e');
      return false;
    }
  }

  /// Unregister from an event (RU only)
  static Future<bool> unregisterFromEvent({
    required String eventId,
    required String jwtToken,
  }) async {
    try {
      final Uri url = Uri.parse('$baseUrl/events/$eventId/register');
      
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Error unregistering from event: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error unregistering from event: $e');
      return false;
    }
  }

  /// Get a specific event by ID
  static Future<Event?> getEvent({required String eventId}) async {
    try {
      final Uri url = Uri.parse('$baseUrl/events/$eventId');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return Event.fromJson(jsonDecode(response.body));
      } else {
        print('Error fetching event: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching event: $e');
      return null;
    }
  }

  /// Check if user is already registered for an event
  static Future<bool> isUserRegistered({
    required String eventId,
    required String jwtToken,
  }) async {
    try {
      final myEvents = await fetchMyEvents(jwtToken: jwtToken);
      return myEvents.any((event) => event.id == eventId);
    } catch (e) {
      print('Error checking registration status: $e');
      return false;
    }
  }
}