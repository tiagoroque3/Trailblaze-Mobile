import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailblaze_app/screens/login_screen.dart';
import 'package:trailblaze_app/screens/user_details_screen.dart';
import 'package:trailblaze_app/screens/operation_screen.dart';
import 'package:trailblaze_app/screens/map_screen.dart'; // Import the new MapScreen

class MainAppScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? jwtToken;
  final String? role; // New: Add role property

  const MainAppScreen({
    super.key,
    this.isLoggedIn = false,
    this.username,
    this.jwtToken,
    this.role, // Initialize role
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _displayUsername;
  String? _displayRole; // State variable to hold the role

  @override
  void initState() {
    super.initState();
    _displayUsername = widget.username;
    _displayRole = widget.role;

    // If logged in but role isn't provided (e.g., direct access or old login flow), fetch it.
    if (widget.isLoggedIn && _displayRole == null) {
      _fetchUserRole();
    }
  }

  /// Fetches the user's role from the backend.
  /// This is called if the role isn't available when MainAppScreen loads.
  Future<void> _fetchUserRole() async {
    if (widget.username == null || widget.jwtToken == null) {
      print('Cannot fetch role: username or JWT token is null.');
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
          _displayRole = userData['role'] as String?;
          if (_displayRole == null) {
            print('Role not found in user details response.');
          }
        });
      } else {
        print('Failed to fetch user role: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  // --- Authentication/Navigation Methods ---

  Future<void> _logout() async {
    // Potentially show a loading indicator here if needed for logout API call
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

    // Clear locally stored token and navigate back to WelcomeScreen
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwtToken');
    await prefs.remove('username');
    await prefs.remove('userRole'); // Clear role from shared preferences

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()), // Go back to login screen
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  void _showGuestLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Acesso Restrito'),
          content: const Text('Por favor, faça login para aceder a esta funcionalidade.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: const Text('Ir para Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Assign the key to Scaffold
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F695B),
        leading: IconButton(
          icon: const Icon(Icons.menu), // Three lines button
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer(); // Open the drawer
          },
        ),
        title: Column( // Use a Column for multiline title
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isLoggedIn ? 'Olá, ${_displayUsername ?? 'Utilizador'}!' : 'Olá Visitante!', // Show username or "Olá Visitante!"
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.isLoggedIn && _displayRole != null) // Conditionally display role
              Text(
                'Cargo: ${_displayRole!}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          // Logout button or Login button
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
                      MaterialPageRoute(builder: (context) => LoginScreen()),
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
          const SizedBox(width: 10), // Add some spacing to the right of the button
        ],
        toolbarHeight: 60, // Adjust height if needed
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
                widget.isLoggedIn ? 'Bem-vindo, ${_displayUsername ?? 'Utilizador'}' : 'Modo Visitante',
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
                Navigator.pop(context); // Close the drawer
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
                Navigator.pop(context); // Close the drawer
                if (widget.isLoggedIn && widget.username != null && widget.jwtToken != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OperationScreen(
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
              leading: const Icon(Icons.map), // Map icon
              title: const Text('View Map'), // New menu item for the map
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // The map screen can be accessed by both logged-in and guest users.
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
            // Add more menu items here
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png', // Display the logo
              height: 200,
            ),
            const SizedBox(height: 20),
            Text(
              'Bem-vindo à TrailBlaze App!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.isLoggedIn
                  ? 'Você está logado como ${_displayUsername ?? 'Utilizador'}.'
                  : 'Você está no modo de visitante. Algumas funcionalidades podem estar limitadas.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer(); // Open drawer on button press
              },
              icon: const Icon(Icons.menu, color: Colors.white),
              label: const Text(
                'Abrir Menu',
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
