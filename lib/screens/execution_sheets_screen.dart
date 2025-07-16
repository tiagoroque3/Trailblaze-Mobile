import 'package:flutter/material.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/utils/role_manager.dart';
import 'package:trailblaze_app/screens/prbo_execution_sheets_screen.dart';
import 'package:trailblaze_app/screens/po_execution_sheets_screen.dart';

class ExecutionSheetsScreen extends StatelessWidget {
  final List<String> roles;
  final String jwtToken;
  final String username;

  const ExecutionSheetsScreen({
    super.key,
    required this.roles,
    required this.jwtToken,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final roleManager = RoleManager(roles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution Sheets'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: _buildRoleBasedView(context, roleManager),
    );
  }

  Widget _buildRoleBasedView(BuildContext context, RoleManager roleManager) {
    // Users with PRBO or SDVBO roles get the PRBO view.
    if (roleManager.isPrbo || roleManager.isSdvbo) {
      return PrboExecutionSheetsView(
        jwtToken: jwtToken,
        username: username,
      );
    } 
    // Users with PO role get the PO view.
    else if (roleManager.isPo) {
      return PoExecutionSheetsView(
        jwtToken: jwtToken,
        username: username,
      );
    } 
    // Fallback for users without the required roles.
    else {
      return const Center(
        child: Text(
          'You do not have the permissions to view this page.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
  }
}