import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/screens/main_app_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailblaze_app/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Fetches detailed user information, including the role.
  /// This is a helper function to get the full user data after login.
  Future<Map<String, dynamic>?> _fetchUserDetails(String username, String jwtToken) async {
    final Uri userDetailsUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/account/details/$username');

    try {
      final response = await http.get(
        userDetailsUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to load user details for role: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user details for role: $e');
      return null;
    }
  }

  Future<void> _loginButtonPressed() async {
    setState(() {
      _isLoading = true;
    });

    final String username = _usernameController.text;
    final String password = _passwordController.text;

    final Uri loginUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/login-jwt');

    try {
      final response = await http.post(
        loginUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final String token = responseBody['token'];

        // Now, fetch the full user details to get the role
        final Map<String, dynamic>? userData = await _fetchUserDetails(username, token);
        String? userRole = userData?['role'] as String?;

        // Store token, username, and role locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwtToken', token);
        await prefs.setString('username', username);
        if (userRole != null) {
          await prefs.setString('userRole', userRole);
        }

        print('Login successful! Token: $token, Role: $userRole');

        // Navigate to MainAppScreen, passing login details and role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainAppScreen(
              isLoggedIn: true,
              username: username,
              jwtToken: token,
              role: userRole, // Pass the fetched role
            ),
          ),
        );
      } else {
        final String errorMessage = response.body;
        print('Login failed: ${response.statusCode} - ${response.body}');
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print('Error during login: $e');
      _showErrorDialog('An error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
          content: Text(message),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F695B), // Your primary green
              Color(0xFF7f9e8e), // Lighter green for gradient
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0), // Padding around the card
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450), // Max width similar to CSS
              child: Container(
                padding: const EdgeInsets.all(40.0), // Padding inside the card
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95), // White with slight transparency
                  borderRadius: BorderRadius.circular(20.0), // Rounded corners for the card
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20, // Increased blur for a softer shadow
                      offset: const Offset(0, 10), // Adjusted offset
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Wrap content tightly
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Column( // Group logo and text
                      children: [
                        Image.asset(
                          'assets/images/logo.png', // Your logo
                          height: 100,
                          width: 100, // Ensure width is set for proper scaling
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28.0,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4F695B), // Use primary green
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.0,
                            color: const Color(0xFF7f9e8e), // Lighter green text
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30.0),
                    TextField(
                      controller: _usernameController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Username or Email',
                        hintText: 'Enter your username or email', // Hint text
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Color(0xFFe0e0e0), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF4F695B)), // Icon color
                      ),
                    ),
                    const SizedBox(height: 20.0), // Space adjusted to match CSS
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password', // Hint text
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Color(0xFFe0e0e0), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF4F695B)), // Icon color
                      ),
                    ),
                    const SizedBox(height: 25.0), // Space adjusted to match CSS
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Container( // Wrap button for gradient
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4F695B), // Your primary green
                                  Color(0xFF7f9e8e), // Lighter green for gradient
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [ // Add button shadow on hover effect
                                BoxShadow(
                                  color: const Color(0xFF4F695B).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            ),
                            child: ElevatedButton(
                              onPressed: _loginButtonPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent, // Make button transparent to show gradient
                                shadowColor: Colors.transparent, // No shadow from button itself
                                padding: const EdgeInsets.symmetric(vertical: 14.0), // Adjusted padding
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                elevation: 0, // No default elevation
                              ),
                              child: const Text(
                                'Sign In', // Changed text to "Sign In"
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20.0),
                    Row( // Divider for 'or'
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFe0e0e0))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: const Color(0xFF7f9e8e),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFe0e0e0))),
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: TextStyle(color: const Color(0xFF7f9e8e), fontSize: 16),
                          children: [
                            TextSpan(
                              text: 'Create Account', // Changed text
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    TextButton(
                      onPressed: () {
                        // Implement back to home/welcome screen logic if needed
                        Navigator.pop(context); // Goes back to WelcomeScreen
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7f9e8e), // Lighter green for text button
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('← Back to Home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
