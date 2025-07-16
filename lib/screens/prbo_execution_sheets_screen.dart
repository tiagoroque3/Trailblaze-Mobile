import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/screens/prbo_execution_sheet_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PrboExecutionSheetsView extends StatefulWidget {
  final String jwtToken;
  final String username;

  const PrboExecutionSheetsView(
      {super.key, required this.jwtToken, required this.username});

  @override
  _PrboExecutionSheetsViewState createState() =>
      _PrboExecutionSheetsViewState();
}

class _PrboExecutionSheetsViewState extends State<PrboExecutionSheetsView> {
  Future<List<ExecutionSheet>>? _sheetsFuture;
  bool _showOnlyMine = false;

  @override
  void initState() {
    super.initState();
    _sheetsFuture = _fetchExecutionSheets();
  }

  Future<List<ExecutionSheet>> _fetchExecutionSheets() async {
    // This endpoint should return all execution sheets for the logged-in user.
    final response = await http.get(
      Uri.parse('https://trailblaze-460312.appspot.com/rest/fe'),
      headers: {'Authorization': 'Bearer ${widget.jwtToken}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ExecutionSheet.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load execution sheets');
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
              const Text('See only mine'),
              Switch(
                value: _showOnlyMine,
                onChanged: (value) {
                  setState(() {
                    _showOnlyMine = value;
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
                if (_showOnlyMine) {
                  sheets = sheets
                      .where((sheet) => sheet.associatedUser == widget.username)
                      .toList();
                }

                if (sheets.isEmpty) {
                  return const Center(child: Text('No execution sheets found.'));
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
                              builder: (context) => ExecutionSheetDetailsScreen(
                                sheet: sheet,
                                jwtToken: widget.jwtToken,
                              ),
                            ),
                          );
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