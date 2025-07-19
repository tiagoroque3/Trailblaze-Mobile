

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:trailblaze_app/screens/login_screen.dart';
import 'package:trailblaze_app/screens/user_details_screen.dart';
import 'package:trailblaze_app/screens/po_execution_dashboard.dart';
import 'package:trailblaze_app/screens/execution_sheets_screen.dart';
import 'package:trailblaze_app/screens/map_screen.dart';
import 'package:trailblaze_app/screens/events_screen.dart';
import 'package:trailblaze_app/utils/role_manager.dart';

class MainAppScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? jwtToken;
  final List<String>? roles;

  const MainAppScreen({
    super.key,
    this.isLoggedIn = false,
    this.username,
    this.jwtToken,
    this.roles,
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _storage = const FlutterSecureStorage();

  String? _displayUsername;
  List<String>? _displayRoles;

  @override
  void initState() {
    super.initState();
    _displayUsername = widget.username;
    _displayRoles = widget.roles;

    if (widget.isLoggedIn &&
        (_displayRoles == null || _displayRoles!.isEmpty)) {
      _loadAndFetchRoles();
    }
  }

  Future<void> _loadAndFetchRoles() async {
    await _loadRolesFromStorage();
    await _fetchUserRoles();
  }

  Future<void> _loadRolesFromStorage() async {
    try {
      final storedRoles = await _storage.read(key: 'userRoles');
      if (storedRoles != null && mounted) {
        final List<dynamic> rolesList = jsonDecode(storedRoles);
        setState(() => _displayRoles = rolesList.cast<String>());
      }
    } catch (_) {}
  }

  Future<void> _fetchUserRoles() async {
    if (widget.username == null || widget.jwtToken == null) return;
    final url = Uri.parse(
      'https://trailblaze-460312.appspot.com/rest/account/details/${widget.username}',
    );
    try {
      final resp = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _displayRoles = (data['roles'] as List<dynamic>?)?.cast<String>();
        });
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    if (widget.jwtToken != null) {
      final url = Uri.parse(
        'https://trailblaze-460312.appspot.com/rest/logout/jwt',
      );
      try {
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.jwtToken}',
          },
        );
      } catch (_) {}
    }
    await _storage.delete(key: 'jwtToken');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'userRoles');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showGuestLoginDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restricted Access'),
        content: const Text('Please log in to access this feature.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Go to Login'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showRoleRequiredDialog(String role) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Insufficient Permissions'),
        content: Text('You need the "$role" role to access this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool get _isRUorAdmin =>
      _displayRoles?.contains('RU') == true ||
      _displayRoles?.contains('SYSADMIN') == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F695B),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          widget.isLoggedIn
              ? 'Hello, ${_displayUsername ?? 'User'}!'
              : 'Hello Guest!',
          style: const TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        toolbarHeight: 60,
        actions: [
          widget.isLoggedIn
              ? ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF4F695B)),
              child: Text(
                widget.isLoggedIn
                    ? 'Welcome, ${_displayUsername ?? 'User'}'
                    : 'Guest Mode',
                style:
                    const TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            // User Details
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('User Details'),
              onTap: () {
                Navigator.pop(context);
                if (widget.isLoggedIn &&
                    widget.username != null &&
                    widget.jwtToken != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserDetailsScreen(
                        username: widget.username!,
                        jwtToken: widget.jwtToken!,
                      ),
                    ),
                  );
                } else {
                  _showGuestLoginDialog();
                }
              },
            ),
            // PO
            if (_displayRoles?.contains('PO') == true)
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Field Operations'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.isLoggedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PoExecutionDashboard(
                          username: widget.username!,
                          jwtToken: widget.jwtToken!,
                        ),
                      ),
                    );
                  } else {
                    _showGuestLoginDialog();
                  }
                },
              ),
            // PRBO
            if (_displayRoles?.contains('PRBO') == true)
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Execution Sheets'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.isLoggedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExecutionSheetsScreen(
                          username: widget.username!,
                          jwtToken: widget.jwtToken!,
                          roles: _displayRoles!,
                        ),
                      ),
                    );
                  } else {
                    _showGuestLoginDialog();
                  }
                },
              ),
            // View Map
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('View Map'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      username: widget.username,
                      jwtToken: widget.jwtToken,
                    ),
                  ),
                );
              },
            ),
            // Events
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Events'),
              onTap: () {
                Navigator.pop(context);
                if (widget.isLoggedIn && _displayRoles?.contains('RU') == true) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventsScreen(
                        username: widget.username!,
                        jwtToken: widget.jwtToken!,
                        userRoles: _displayRoles,
                      ),
                    ),
                  );
                } else if (!widget.isLoggedIn) {
                  _showGuestLoginDialog();
                } else {
                  _showRoleRequiredDialog('RU');
                }
              },
            ),
     
            // Management Divider
            if (_displayRoles != null &&
                (_displayRoles!.contains('PRBO') ||
                    _displayRoles!.contains('SDVBO') ||
                    _displayRoles!.contains('SYSADMIN'))) ...[
              const Divider(),
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Execution Management'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Management interface coming soon'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', height: 200),
              const SizedBox(height: 20),
              Text(
                'Welcome to the TrailBlaze App!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                widget.isLoggedIn
                    ? 'You are logged in as ${_displayUsername ?? 'User'}.\n${_buildRoleDescription()}'
                    : 'You are in guest mode. Some features may be limited.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: Colors.white),
                label: const Text('Open Menu',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F695B),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildRoleDescription() {
    if (_displayRoles == null || _displayRoles!.isEmpty) {
      return 'No roles assigned';
    }
    final rm = RoleManager(_displayRoles!);
    final List<String> descs = [];
    if (rm.isPo) descs.add('Field Operator');
    if (rm.isPrbo) descs.add('Project Manager');
    if (rm.isSdvbo) descs.add('System Manager');
    if (_displayRoles!.contains('RU')) descs.add('Event Participant');
    if (_displayRoles!.contains('SYSADMIN'))
      descs.add('System Administrator');
    return descs.isNotEmpty ? descs.join(' • ') : _displayRoles!.join(', ');
  }
}
