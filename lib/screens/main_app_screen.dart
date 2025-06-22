import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailblaze_app/screens/login_screen.dart';
import 'package:trailblaze_app/screens/user_details_screen.dart'; // New screen

class MainAppScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? jwtToken;

  const MainAppScreen({
    super.key,
    this.isLoggedIn = false,
    this.username,
    this.jwtToken,
  });

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _logout() async {
    setState(() {
      // Potentially show a loading indicator here if needed for logout API call
    });

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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()), // Go back to login screen
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // Assign the key to Scaffold
      appBar: AppBar(
        backgroundColor: Color(0xFF4F695B),
        leading: IconButton(
          icon: const Icon(Icons.menu), // Three lines button
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer(); // Open the drawer
          },
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.isLoggedIn ? widget.username! : 'Olá Visitante!', // Show username or "Olá Visitante!"
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Placeholder for notifications (middle part)
            const Spacer(),
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
          ],
        ),
        toolbarHeight: 60, // Adjust height if needed
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF4F695B),
              ),
              child: Text(
                widget.isLoggedIn ? 'Bem-vindo, ${widget.username}' : 'Modo Visitante',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: const Text('User Details'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                if (widget.isLoggedIn) {
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
            // Add more menu items here
          ],
        ),
      ),
      body: Center(
        child: Text('Notificações e Conteúdo Principal Aqui'),
      ),
    );
  }

  void _showGuestLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Acesso Restrito'),
          content: const Text('Por favor, faça login para aceder aos detalhes do utilizador.'),
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
}