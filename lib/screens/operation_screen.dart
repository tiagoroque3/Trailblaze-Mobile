import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/activity.dart';
import 'package:trailblaze_app/models/operation.dart'; // Ensure this import is correct
import 'package:trailblaze_app/models/occurrence.dart'; // Ensure this import is correct
import 'package:trailblaze_app/utils/create_occurrence_request.dart';

class OperationScreen extends StatefulWidget {
  final String username;
  final String jwtToken;

  const OperationScreen({
    super.key,
    required this.username,
    required this.jwtToken,
  });

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  final TextEditingController _operationIdController = TextEditingController();
  final TextEditingController _executionSheetIdController = TextEditingController(); // For creating occurrences
  final TextEditingController _incidentTypeController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();

  bool _isLoading = false;
  List<Activity> _activities = [];
  List<Occurrence> _occurrences = [];

  @override
  void dispose() {
    _operationIdController.dispose();
    _executionSheetIdController.dispose();
    _incidentTypeController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /*
   * PO Operations
   */

  // START-ACT-OP-FE: Start an activity for a given operation
  // Endpoint: POST /operations/{operationId}/start
  Future<void> _startActivity() async {
    setState(() {
      _isLoading = true;
    });

    final String operationId = _operationIdController.text.trim();

    if (operationId.isEmpty) {
      _showSnackBar('Operation ID cannot be empty.', isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/$operationId/start');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final Activity activity = Activity.fromJson(responseBody);
        _showSnackBar('Activity started successfully! Activity ID: ${activity.id}');
      } else {
        _showSnackBar('Failed to start activity: ${response.statusCode} - ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error starting activity: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // STOP-ACT-OP-FE: Stop an activity for a given operation
  // Endpoint: POST /operations/{operationId}/stop
  Future<void> _stopActivity() async {
    setState(() {
      _isLoading = true;
    });

    final String operationId = _operationIdController.text.trim();

    if (operationId.isEmpty) {
      _showSnackBar('Operation ID cannot be empty.', isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/$operationId/stop');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final Activity activity = Activity.fromJson(responseBody);
        _showSnackBar('Activity stopped successfully! Activity ID: ${activity.id}');
      } else {
        _showSnackBar('Failed to stop activity: ${response.statusCode} - ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error stopping activity: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // VIEW-ACT-OP-FE: View activities for a specific operation
  // Endpoint: GET /operations/{operationId}/activities
  Future<void> _viewActivitiesForOperation() async {
    setState(() {
      _isLoading = true;
      _activities = [];
    });

    final String operationId = _operationIdController.text.trim();

    if (operationId.isEmpty) {
      _showSnackBar('Operation ID cannot be empty to view activities.', isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('https://trailblaze-460312.appspot.com/rest/operations/$operationId/activities');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        setState(() {
          _activities = jsonList.map((json) => Activity.fromJson(json)).toList();
        });
        if (_activities.isEmpty) {
          _showSnackBar('No activities found for this operation.');
        } else {
          _showInfoDialog('Activities for Operation $operationId', _activities.map((e) => 'ID: ${e.id}\nOperator: ${e.operatorId}\nStart: ${e.startTime.toLocal().toString()}\nEnd: ${e.endTime?.toLocal().toString() ?? 'N/A'}\nObs: ${e.observations ?? 'N/A'}\nPhotos: ${e.photos.isNotEmpty ? e.photos.join(', ') : 'N/A'}\nGPS: ${e.gpsTracks.isNotEmpty ? e.gpsTracks.join(', ') : 'N/A'}').join('\n\n---\n\n'));
        }
      } else {
        _showSnackBar('Failed to view activities: ${response.statusCode} - ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error viewing activities: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // CREATE OCCURRENCE (Observations): As per user's clarification "add observations (which should be occurrences)"
  // Endpoint: POST /occ/{sheetId}
  Future<void> _createOccurrence() async {
    setState(() {
      _isLoading = true;
    });

    final String executionSheetId = _executionSheetIdController.text.trim();
    final String incidentType = _incidentTypeController.text.trim();
    final String description = _observationsController.text.trim();

    if (executionSheetId.isEmpty || incidentType.isEmpty || description.isEmpty) {
      _showSnackBar('All fields (Execution Sheet ID, Incident Type, Description) are required to create an occurrence.', isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('https://trailblaze-460312.appspot.com/rest/occ/$executionSheetId');

    final CreateOccurrenceRequest requestBody = CreateOccurrenceRequest(
      incidentType: incidentType,
      description: description,
      evidenceUrls: [], // No photo/GPS upload functionality implemented in Flutter for now
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
        body: jsonEncode(requestBody.toJson()),
      );

      if (response.statusCode == 201) { // 201 Created for successful creation
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final Occurrence newOccurrence = Occurrence.fromJson(responseBody);
        _showSnackBar('Occurrence created successfully! ID: ${newOccurrence.id}');
        _incidentTypeController.clear();
        _observationsController.clear();
      } else {
        _showSnackBar('Failed to create occurrence: ${response.statusCode} - ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error creating occurrence: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // List Occurrences for a given Execution Sheet (for PO to see their observations)
  // Endpoint: GET /occ/fe/{sheetId}
  Future<void> _listOccurrencesForSheet() async {
    setState(() {
      _isLoading = true;
      _occurrences = [];
    });

    final String executionSheetId = _executionSheetIdController.text.trim();

    if (executionSheetId.isEmpty) {
      _showSnackBar('Execution Sheet ID cannot be empty to list occurrences.', isError: true);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Uri url = Uri.parse('https://trailblaze-460312.appspot.com/rest/occ/fe/$executionSheetId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        setState(() {
          _occurrences = jsonList.map((json) => Occurrence.fromJson(json)).toList();
        });
        if (_occurrences.isEmpty) {
          _showSnackBar('No occurrences found for this Execution Sheet.');
        } else {
          _showInfoDialog('Occurrences for Execution Sheet $executionSheetId', _occurrences.map((e) => 'ID: ${e.id}\nType: ${e.incidentType}\nDesc: ${e.description}\nState: ${e.state}\nCreated By: ${e.createdBy}').join('\n\n---\n\n'));
        }
      } else {
        _showSnackBar('Failed to list occurrences: ${response.statusCode} - ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error listing occurrences: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator (PO) Dashboard'),
        backgroundColor: const Color(0xFF4F695B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Manage Activities (START/STOP):',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'To interact with an operation, please enter its unique ID below.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _operationIdController,
              decoration: const InputDecoration(
                labelText: 'Operation ID (UUID)',
                hintText: 'e.g., 123e4567-e89b-12d3-a456-426614174000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: _startActivity,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F695B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                        child: const Text('START ACTIVITY'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _stopActivity,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F695B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                        child: const Text('STOP ACTIVITY'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _viewActivitiesForOperation,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F695B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                        child: const Text('VIEW ACTIVITIES FOR OPERATION'),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Create and View Observations (Occurrences):',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Occurrences are associated with an Execution Sheet. Please enter the Execution Sheet ID.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _executionSheetIdController,
                        decoration: const InputDecoration(
                          labelText: 'Execution Sheet ID (UUID)',
                          hintText: 'e.g., abcd1234-5678-90ef-ghij-1234567890ab',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _incidentTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Incident Type (e.g., "Observation", "Damage")',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _observationsController,
                        decoration: const InputDecoration(
                          labelText: 'Description/Observations',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _createOccurrence,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                        child: const Text('CREATE NEW OBSERVATION (OCCURRENCE)'),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _listOccurrencesForSheet,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(fontSize: 16)),
                        child: const Text('VIEW OBSERVATIONS FOR SHEET'),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Note: This screen requires you to manually enter Operation IDs or Execution Sheet IDs. '
                        'To view operations specifically assigned to you, a new backend endpoint would be needed.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}