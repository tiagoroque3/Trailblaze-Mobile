import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/screens/po_execution_sheet_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoExecutionSheetsView extends StatefulWidget {
  final String jwtToken;
  final String username;

  const PoExecutionSheetsView(
      {super.key, required this.jwtToken, required this.username});

  @override
  _PoExecutionSheetsViewState createState() => _PoExecutionSheetsViewState();
}

class _PoExecutionSheetsViewState extends State<PoExecutionSheetsView> {
  Future<List<ExecutionSheet>>? _sheetsFuture;
  bool _showOnlyMyAssigned = false;
  List<ExecutionSheet> _allSheets = [];

  @override
  void initState() {
    super.initState();
    _sheetsFuture = _fetchAndProcessExecutionSheets();
  }

  Future<List<ExecutionSheet>> _fetchAndProcessExecutionSheets() async {
    final response = await http.get(
      Uri.parse('https://trailblaze-460312.appspot.com/rest/fe'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      _allSheets = data.map((json) => ExecutionSheet.fromJson(json)).toList();

      // Asynchronously fetch details for all sheets to check for assignments
      await _checkAssignments();

      return _allSheets;
    } else {
      throw Exception('Failed to load execution sheets');
    }
  }

  Future<void> _checkAssignments() async {
    for (var sheet in _allSheets) {
      try {
        final response = await http.get(
          Uri.parse('https://trailblaze-460312.appspot.com/rest/fe/${sheet.id}'),
          headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
        );
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final List<dynamic> operationsData = data['operations'] ?? [];
          sheet.isAssignedToCurrentUser = operationsData.any((opData) {
            final List<dynamic> parcelsData = opData['parcels'] ?? [];
            return parcelsData.any((parcelData) {
              final List<dynamic> activities = parcelData['activities'] ?? [];
              return activities.any((activity) => activity['operatorId'] == widget.username);
            });
          });
        }
      } catch (e) {
        // Ignore errors for individual sheet details, it just won't be marked as assigned
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Show only my assigned'),
              Switch(
                value: _showOnlyMyAssigned,
                onChanged: (value) {
                  setState(() {
                    _showOnlyMyAssigned = value;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ExecutionSheet>>(
            future: _sheetsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                  color: AppColors.primaryGreen,
                ));
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No execution sheets found.'));
              } else {
                var sheets = snapshot.data!;
                if (_showOnlyMyAssigned) {
                  sheets = sheets
                      .where((sheet) => sheet.isAssignedToCurrentUser)
                      .toList();
                }

                if (sheets.isEmpty) {
                  return const Center(child: Text('No sheets with assigned operations found.'));
                }

                return ListView.builder(
                  itemCount: sheets.length,
                  itemBuilder: (context, index) {
                    final sheet = sheets[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(sheet.title),
                        subtitle: Text('Status: ${sheet.state}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PoExecutionSheetDetailsScreen(
                                sheet: sheet,
                                jwtToken: widget.jwtToken,
                                username: widget.username,
                              ),
                            ),
                          ).then((_) => setState(() {
                            // Refresh data when coming back from details screen
                            _sheetsFuture = _fetchAndProcessExecutionSheets();
                          }));
                        },
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}