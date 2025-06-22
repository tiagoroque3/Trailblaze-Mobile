import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trailblaze_app/screens/login_screen.dart'; // To navigate to login after successful registration

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  bool _isPublicProfile = false; // Default to private
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _registerButtonPressed() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('As palavras-passe não correspondem.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String username = _usernameController.text;
    final String email = _emailController.text;
    final String password = _passwordController.text;
    final String fullName = _fullNameController.text;

    final Uri registerUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/register/civic');

    try {
      final response = await http.post(
        registerUrl,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'isPublic': _isPublicProfile, // Send the profile visibility preference
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 201) { // 201 Created for successful registration
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conta registada com sucesso! Aguarda ativação.')),
        );
        // Navigate to login screen after successful registration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        final String errorMessage = response.body;
        print('Registo falhou: ${response.statusCode} - $errorMessage');
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Erro durante o registo: $e');
      _showErrorDialog('Ocorreu um erro. Por favor, tente novamente.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erro no Registo'),
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
      appBar: AppBar(
        title: const Text('Registar Conta'),
        backgroundColor: Color(0xFF4F695B),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Criar Nova Conta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F695B),
                ),
              ),
              const SizedBox(height: 30.0),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  prefixIcon: const Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  prefixIcon: const Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16.0),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                  prefixIcon: const Icon(Icons.lock_reset),
                ),
              ),
              const SizedBox(height: 16.0),
              SwitchListTile(
                title: const Text('Tornar Perfil Público'),
                value: _isPublicProfile,
                onChanged: (bool value) {
                  setState(() {
                    _isPublicProfile = value;
                  });
                },
                secondary: Icon(_isPublicProfile ? Icons.public : Icons.vpn_lock),
              ),
              const SizedBox(height: 24.0),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _registerButtonPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4F695B),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Text(
                        'Registar',
                        style: TextStyle(fontSize: 18.0, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}