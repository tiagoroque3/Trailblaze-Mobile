import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/screens/main_app_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final _storage = const FlutterSecureStorage();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Parse JWT token to extract payload
  Map<String, dynamic> _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print('Invalid JWT format: expected 3 parts, got ${parts.length}');
        return {};
      }

      final payload = parts[1];
      // Add padding if needed for base64 decoding
      var normalizedPayload = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      print('Decoded JWT payload: $decoded'); // Debug print
      
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing JWT: $e');
      return {};
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

        // Decode the token to get the roles directly
        final Map<String, dynamic> jwtPayload = _parseJwt(token);
        print('JWT Payload: $jwtPayload'); // Debug print
        
        final List<String> userRoles = (jwtPayload['roles'] as List<dynamic>?)?.cast<String>() ?? [];
        print('Extracted roles: $userRoles'); // Debug print

        // Store token, username, and roles securely
        await _storage.write(key: 'jwtToken', value: token);
        await _storage.write(key: 'username', value: username);
        await _storage.write(key: 'userRoles', value: jsonEncode(userRoles));

        print('Login successful! Token: $token, Roles: $userRoles');

        // Navigate to the main app screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainAppScreen(
              isLoggedIn: true,
              username: username,
              jwtToken: token,
              roles: userRoles,
            ),
          ),
        );
      } else {
        final String errorMessage = response.body;
        print('Login failed: ${response.statusCode} - $errorMessage');
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
              Color(0xFF4F695B),
              Color(0xFF7f9e8e),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                padding: const EdgeInsets.all(40.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 100,
                          width: 100,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F695B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to continue your journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Color(0xFF7f9e8e),
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
                        hintText: 'Enter your username or email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Color(0xFFe0e0e0), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF4F695B)),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: const BorderSide(color: Color(0xFFe0e0e0), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF4F695B)),
                      ),
                    ),
                    const SizedBox(height: 25.0),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4F695B),
                                  Color(0xFF7f9e8e),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: [
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
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20.0),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFe0e0e0))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15.0),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Color(0xFF7f9e8e),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFe0e0e0))),
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
                          style: const TextStyle(color: Color(0xFF7f9e8e), fontSize: 16),
                          children: [
                            TextSpan(
                              text: 'Create Account',
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
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF7f9e8e),
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