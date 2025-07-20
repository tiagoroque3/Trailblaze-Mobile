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
import 'package:trailblaze_app/screens/trails_screen.dart';
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
                      horizontal: 10,
                      vertical: 5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                      horizontal: 10,
                      vertical: 5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                style: const TextStyle(color: Colors.white, fontSize: 24),
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
            // Events (RU only)
            if (_displayRoles?.contains('RU') == true)
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Events'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.isLoggedIn) {
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
                  } else {
                    _showGuestLoginDialog();
                  }
                },
              ),
            // Trails (RU or Admin)
            if (_isRUorAdmin)
              ListTile(
                leading: const Icon(Icons.route),
                title: const Text('Trails'),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.isLoggedIn) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrailsScreen(
                          username: widget.username!,
                          jwtToken: widget.jwtToken!,
                          userRoles: _displayRoles!,
                        ),
                      ),
                    );
                  } else {
                    _showGuestLoginDialog();
                  }
                },
              ),
            // Management section was removed per user request

          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with logo and welcome
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F695B), Color(0xFF6B8A7A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Image.asset('assets/images/logo.png', height: 120),
                    const SizedBox(height: 15),
                    Text(
                      widget.isLoggedIn
                          ? 'Welcome, ${_displayUsername ?? 'User'}!'
                          : 'Guest Mode',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isLoggedIn
                          ? _buildRoleDescription()
                          : 'Some features may be limited',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Quick Access section
              if (widget.isLoggedIn) ...[
                Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 15),

                // Main features grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    // User Details
                    _buildFeatureCard(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'View account details',
                      color: Colors.blue,
                      onTap: () {
                        if (widget.username != null &&
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
                        }
                      },
                    ),

                    // Map
                    _buildFeatureCard(
                      icon: Icons.map_outlined,
                      title: 'Map',
                      subtitle: 'Explore locations',
                      color: Colors.green,
                      onTap: () {
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

                    // PO specific
                    if (_displayRoles?.contains('PO') == true)
                      _buildFeatureCard(
                        icon: Icons.build_outlined,
                        title: 'Operations',
                        subtitle: 'Field operations',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PoExecutionDashboard(
                                username: widget.username!,
                                jwtToken: widget.jwtToken!,
                              ),
                            ),
                          );
                        },
                      ),

                    // PRBO specific
                    if (_displayRoles?.contains('PRBO') == true)
                      _buildFeatureCard(
                        icon: Icons.assignment_outlined,
                        title: 'Sheets',
                        subtitle: 'Execution sheets',
                        color: Colors.purple,
                        onTap: () {
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
                        },
                      ),

                    // Events (RU)
                    if (_displayRoles?.contains('RU') == true)
                      _buildFeatureCard(
                        icon: Icons.event_outlined,
                        title: 'Events',
                        subtitle: 'Participate in events',
                        color: Colors.red,
                        onTap: () {
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
                        },
                      ),

                    // Trails (RU or Admin)
                    if (_isRUorAdmin)
                      _buildFeatureCard(
                        icon: Icons.route_outlined,
                        title: 'Trails',
                        subtitle: 'Manage trails',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrailsScreen(
                                username: widget.username!,
                                jwtToken: widget.jwtToken!,
                                userRoles: _displayRoles!,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 25),
              ],

              // Recent Activity section
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFF4F695B),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'About TrailBlaze',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'TrailBlaze is a complete platform for managing trails and outdoor activities. '
                        'Explore maps, participate in events and manage your field operations efficiently.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                          icon: const Icon(Icons.menu, size: 20),
                          label: const Text('View All Features'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F695B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!widget.isLoggedIn) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 3,
                  color: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.login_outlined,
                          size: 48,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Login for Full Access',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Access all TrailBlaze features by logging into your account.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.login, size: 20),
                            label: const Text('Login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
    if (_displayRoles!.contains('SYSADMIN')) descs.add('System Administrator');
    return descs.isNotEmpty ? descs.join(' • ') : _displayRoles!.join(', ');
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
