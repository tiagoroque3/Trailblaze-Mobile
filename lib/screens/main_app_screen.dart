import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trailblaze_app/screens/login_screen.dart';
import 'package:trailblaze_app/screens/user_details_screen.dart';
import 'package:trailblaze_app/screens/operation_screen.dart';
import 'package:trailblaze_app/screens/map_screen.dart';

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

    if (widget.isLoggedIn && _displayRoles == null) {
      _fetchUserRoles();
    }
  }

  /// Fetches the user's roles from the backend.
  Future<void> _fetchUserRoles() async {
    if (widget.username == null || widget.jwtToken == null) {
      print('Cannot fetch user roles: username or JWT token is null.');
      return;
    }

    final Uri userDetailsUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/account/details/${widget.username}');

    try {
      final response = await http.get(
        userDetailsUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = jsonDecode(response.body);
        setState(() {
          _displayRoles = (userData['roles'] as List<dynamic>?)?.cast<String>();
          if (_displayRoles == null || _displayRoles!.isEmpty) {
            print('User roles not found or empty in user details response.');
          }
        });
      } else {
        print('Failed to fetch user roles: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching user roles: $e');
    }
  }

  Future<void> _logout() async {
    if (widget.jwtToken != null) {
      final Uri logoutUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/logout/jwt');

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
    await _storage.delete(key: 'userRoles'); // Clear user roles from secure storage

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
          content: Text('You need the "$requiredRole" role to access this feature.'),
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
          widget.isLoggedIn ? 'Hello, ${_displayUsername ?? 'User'}!' : 'Hello Guest!',
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
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              decoration: const BoxDecoration(
                color: Color(0xFF4F695B),
              ),
              child: Text(
                widget.isLoggedIn ? 'Welcome, ${_displayUsername ?? 'User'}' : 'Guest Mode',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('User Details'),
              onTap: () {
                Navigator.pop(context);
                if (widget.isLoggedIn && widget.username != null && widget.jwtToken != null) {
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
              title: const Text('Operation Management (PO)'),
              onTap: () {
                Navigator.pop(context);
                if (widget.isLoggedIn && 
                    widget.username != null && 
                    widget.jwtToken != null &&
                    (_displayRoles?.contains('PO') == true)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OperationScreen(
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
                    _showRoleRequiredDialog(context, 'PO');
                  }
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
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 200,
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}