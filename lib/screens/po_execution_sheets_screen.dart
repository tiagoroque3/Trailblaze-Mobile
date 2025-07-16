import 'package:flutter/material.dart';
import 'package:trailblaze_app/screens/po_execution_dashboard.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PoExecutionDashboard(
      jwtToken: widget.jwtToken,
      username: widget.username,
    );
  }
}