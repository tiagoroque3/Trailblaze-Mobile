import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trailblaze_app/screens/login_screen.dart';
import 'package:trailblaze_app/screens/user_details_screen.dart';
import 'package:trailblaze_app/screens/po_execution_dashboard.dart';
import 'package:trailblaze_app/utils/role_manager.dart';
import 'package:trailblaze_app/screens/map_screen.dart';
import 'package:trailblaze_app/screens/events_screen.dart';

class MainAppScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? jwtToken;
  final List<String>? roles; // List of user roles

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
  List<String>? _displayRoles; // State variable to hold the list of roles

  @override
  void initState() {
    super.initState();
    _displayUsername = widget.username;
    _displayRoles = widget.roles;

    // If the user is logged in but roles are not available (e.g., app restart),
    // then try to load them from storage or fetch them from the server.
    if (widget.isLoggedIn &&
        (_displayRoles == null || _displayRoles!.isEmpty)) {
      _loadAndFetchRoles();
    }
  }

  /// Loads roles from storage and then fetches from the server to ensure data is fresh.
  Future<void> _loadAndFetchRoles() async {
    await _loadRolesFromStorage(); // Try to load from storage for a quick UI update
    await _fetchUserRoles(); // Fetch from server to get the latest roles
  }

  /// Load roles from secure storage as fallback
  Future<void> _loadRolesFromStorage() async {
    try {
      final storedRoles = await _storage.read(key: 'userRoles');
      if (storedRoles != null) {
        // Check if the widget is still mounted before calling setState
        if (!mounted) return;
        final List<dynamic> rolesList = jsonDecode(storedRoles);
        setState(() {
          _displayRoles = rolesList.cast<String>();
        });
        print('Loaded roles from storage: $_displayRoles');
      }
    } catch (e) {
      print('Error loading roles from storage: $e');
    }
  }

  /// Fetches the user's roles from the backend.
  Future<void> _fetchUserRoles() async {
    if (widget.username == null || widget.jwtToken == null) {
      print('Cannot fetch user roles: username or JWT token is null.');
      return;
    }

    final Uri userDetailsUrl = Uri.parse(
      'https://trailblaze-460312.appspot.com/rest/account/details/${widget.username}',
    );

    try {
      final response = await http.get(
        userDetailsUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        // Check if the widget is still mounted before calling setState
        if (!mounted) return;
        final Map<String, dynamic> userData = jsonDecode(response.body);
        print('User data from backend: $userData'); // Debug print

        setState(() {
          _displayRoles = (userData['roles'] as List<dynamic>?)?.cast<String>();
          print('Roles set in state: $_displayRoles'); // Debug print

          if (_displayRoles == null || _displayRoles!.isEmpty) {
            print('User roles not found or empty in user details response.');
          }
        });
      } else {
        print(
          'Failed to fetch user roles: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching user roles: $e');
    }
  }

  Future<void> _logout() async {
    if (widget.jwtToken != null) {
      final Uri logoutUrl = Uri.parse(
        'https://trailblaze-460312.appspot.com/rest/logout/jwt',
      );

      try {
        final response = await http.post(
          logoutUrl,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer ${widget.jwtToken}',
          },
        );

        if (response.statusCode == 200) {
          print('Logout successful!');
        } else {
          print('Logout failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Error during logout: $e');
      }
    }

    await _storage.delete(key: 'jwtToken');
    await _storage.delete(key: 'username');
    await _storage.delete(
      key: 'userRoles',
    ); // Clear user roles from secure storage

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showGuestLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restricted Access'),
          content: const Text('Please log in to access this feature.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Go to Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showRoleRequiredDialog(BuildContext context, String requiredRole) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Insufficient Permissions'),
          content: Text(
            'You need the "$requiredRole" role to access this feature.',
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F695B),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(
          widget.isLoggedIn
              ? 'Hello, ${_displayUsername ?? 'User'}!'
              : 'Hello Guest!',
          style: const TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
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
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
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
        toolbarHeight: 60,
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
                      builder: (context) => UserDetailsScreen(
                        username: widget.username!,
                        jwtToken: widget.jwtToken!,
                      ),
                    ),
                  );
                } else {
                  _showGuestLoginDialog(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Field Operations'),
              onTap: () {
                Navigator.pop(context);
                if (widget.isLoggedIn &&
                    widget.username != null &&
                    widget.jwtToken != null) {
                  final roleManager = RoleManager(_displayRoles ?? []);

                  // Check if user has PO role for field operations
                  if (roleManager.isPo) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PoExecutionDashboard(
                          username: widget.username!,
                          jwtToken: widget.jwtToken!,
                        ),
                      ),
                    );
                  } else if (roleManager.isPrbo || roleManager.isSdvbo) {
                    // For PRBO/SDVBO users, show a message or redirect to appropriate screen
                    _showRoleRequiredDialog(
                      context,
                      'This section is for Production Operators (PO). You have management access.',
                    );
                  } else {
                    _showRoleRequiredDialog(
                      context,
                      'PO (Production Operator)',
                    );
                  }
                } else {
                  _showGuestLoginDialog(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('View Map'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapScreen(
                      username: widget.username,
                      jwtToken: widget.jwtToken,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Events'),
              onTap: () {
                Navigator.pop(context);
                print(
                  'Checking Events access - isLoggedIn: ${widget.isLoggedIn}, roles: $_displayRoles',
                ); // Debug print

                if (widget.isLoggedIn &&
                    widget.username != null &&
                    widget.jwtToken != null &&
                    (_displayRoles?.contains('RU') == true)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventsScreen(
                        username: widget.username!,
                        jwtToken: widget.jwtToken!,
                        userRoles: _displayRoles,
                      ),
                    ),
                  );
                } else {
                  if (!widget.isLoggedIn) {
                    _showGuestLoginDialog(context);
                  } else {
                    print(
                      'Access denied - Current roles: $_displayRoles, Required: RU',
                    ); // Debug print
                    _showRoleRequiredDialog(context, 'RU');
                  }
                }
              },
            ),

            // Add a divider and admin section if user has management roles
            if (_displayRoles != null &&
                (_displayRoles!.contains('PRBO') ||
                    _displayRoles!.contains('SDVBO') ||
                    _displayRoles!.contains('SYSADMIN'))) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  // This would navigate to the PRBO/SDVBO execution management screen
                  // For now, show a placeholder message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Management interface coming soon'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      body: Center(
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
                  ? 'You are logged in as ${_displayUsername ?? 'User'}.\nRoles: ${_displayRoles?.join(', ') ?? 'No roles assigned'}'
                  : 'You are in guest mode. Some features may be limited.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              icon: const Icon(Icons.menu, color: Colors.white),
              label: const Text(
                'Open Menu',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F695B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildRoleDescription() {
    if (_displayRoles == null || _displayRoles!.isEmpty) {
      return 'No roles assigned';
    }

    final roleManager = RoleManager(_displayRoles!);
    List<String> descriptions = [];

    if (roleManager.isPo) {
      descriptions.add('Field Operator');
    }
    if (roleManager.isPrbo) {
      descriptions.add('Project Manager');
    }
    if (roleManager.isSdvbo) {
      descriptions.add('System Manager');
    }
    if (_displayRoles!.contains('RU')) {
      descriptions.add('Event Participant');
    }
    if (_displayRoles!.contains('SYSADMIN')) {
      descriptions.add('System Administrator');
    }

    if (descriptions.isEmpty) {
      return 'Roles: ${_displayRoles!.join(', ')}';
    }

    return descriptions.join(' • ');
  }
}
