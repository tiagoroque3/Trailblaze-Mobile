import 'package:flutter/material.dart';
import 'package:trailblaze_app/screens/prbo_execution_dashboard.dart';

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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PrboExecutionDashboard(
      jwtToken: widget.jwtToken,
      username: widget.username,
    );
  }
}