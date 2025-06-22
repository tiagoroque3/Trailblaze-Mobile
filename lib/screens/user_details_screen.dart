import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailblaze_app/screens/login_screen.dart';

class EditAccountScreen extends StatefulWidget {
  final String username;
  final String jwtToken;
  final Map<String, dynamic> userData; // Now receives all user data

  const EditAccountScreen({
    super.key,
    required this.username,
    required this.jwtToken,
    required this.userData,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  // Controllers for all editable fields based on UpdateRequest.java
  late TextEditingController _fullNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _nationalityController;
  late TextEditingController _residenceCountryController;
  late TextEditingController _nifController;
  late TextEditingController _ccController;
  // Removed _isPublic as it will be handled by a separate resource/method
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data or empty string
    _fullNameController = TextEditingController(text: widget.userData['name'] ?? '');
    _addressController = TextEditingController(text: widget.userData['address'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    _nationalityController = TextEditingController(text: widget.userData['nationality'] ?? '');
    _residenceCountryController = TextEditingController(text: widget.userData['residenceCountry'] ?? '');
    _nifController = TextEditingController(text: widget.userData['nif'] ?? '');
    _ccController = TextEditingController(text: widget.userData['cc'] ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _residenceCountryController.dispose();
    _nifController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    final Uri updateUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/account/update');

    // Only send fields that are part of UpdateRequest.java and are being changed
    // Profile (isPublic) is explicitly removed here.
    final Map<String, dynamic> updateData = {
      'fullName': _fullNameController.text,
      'address': _addressController.text,
      'phone': _phoneController.text,
      'nationality': _nationalityController.text,
      'residenceCountry': _residenceCountryController.text,
      'nif': _nifController.text,
      'cc': _ccController.text,
    };

    try {
      final response = await http.put(
        updateUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conta atualizada com sucesso!')),
        );
        Navigator.pop(context, true); // Pop with 'true' to indicate success and trigger data refresh
      } else {
        _showErrorDialog(context, 'Falha ao atualizar conta: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showErrorDialog(context, 'Erro ao atualizar conta: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erro'),
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
        title: const Text('Editar Conta'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Only editable fields based on UpdateRequest
                  _buildEditableTextField(_fullNameController, 'Nome Completo', Icons.person),
                  _buildEditableTextField(_addressController, 'Morada', Icons.home),
                  _buildEditableTextField(_phoneController, 'Telefone', Icons.phone),
                  _buildEditableTextField(_nationalityController, 'Nacionalidade', Icons.flag),
                  _buildEditableTextField(_residenceCountryController, 'País de Residência', Icons.public),
                  _buildEditableTextField(_nifController, 'NIF', Icons.credit_card),
                  _buildEditableTextField(_ccController, 'Cartão de Cidadão', Icons.credit_card),
                  // Removed SwitchListTile for profile, as it should be handled by ProfileChangeResource
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text('Guardar Alterações'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Use a separate widget for editable text fields
  Widget _buildEditableTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

class UserDetailsScreen extends StatefulWidget {
  final String username;
  final String jwtToken;

  const UserDetailsScreen({
    super.key,
    required this.username,
    required this.jwtToken,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
        setState(() {
          _userData = jsonDecode(response.body); // Decode all returned data
        });
      } else {
        setState(() {
          _error = 'Failed to load user data: ${response.statusCode} - ${response.body}';
        });
        print('Error fetching user details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred while fetching user data: $e';
      });
      print('Exception fetching user details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleProfileVisibility() async {
    setState(() {
      _isLoading = true;
    });

    final Uri toggleProfileUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/profile');

    try {
      final response = await http.post( // Changed to POST as per ProfileChangeResource
        toggleProfileUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perfil alterado com sucesso!')),
        );
        _fetchUserDetails(); // Refresh data to show updated profile status
      } else {
        _showErrorDialog(context, 'Falha ao alterar o perfil: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showErrorDialog(context, 'Erro ao alterar o perfil: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestAccountDeletion() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminação'),
        content: const Text('Tem certeza que deseja solicitar a eliminação da sua conta? Esta ação é irreversível.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Dismiss dialog
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Dismiss dialog
              setState(() {
                _isLoading = true; // Show loading for deletion request
              });

              // This endpoint is still assumed to exist on your backend
              // and perform a 'soft delete' or 'pending removal' action
              final Uri removeRequestUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/account/remove-request');

              try {
                final response = await http.patch( // PATCH request for remove-request
                  removeRequestUrl,
                  headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                    'Authorization': 'Bearer ${widget.jwtToken}',
                  },
                );

                setState(() {
                  _isLoading = false;
                });

                if (response.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pedido de eliminação de conta submetido com sucesso!')),
                  );
                  // Immediately logout after requesting deletion
                  await _logoutUser();
                } else {
                  _showErrorDialog(context, 'Falha ao solicitar eliminação: ${response.statusCode} - ${response.body}');
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                _showErrorDialog(context, 'Erro ao solicitar eliminação: $e');
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _logoutUser() async {
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
        print('Logout successful after deletion request.');
      } else {
        print('Logout failed after deletion request: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error during logout after deletion request: $e');
    }

    // Clear local storage regardless of API logout success
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwtToken');
    await prefs.remove('username');

    // Navigate back to the login screen, clearing all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Erro'),
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
    bool isRuRole = _userData?['role'] == 'RU';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Utilizador'),
        backgroundColor: Colors.blueAccent,
        actions: [
          if (isRuRole) // Only show the button if the role is 'RU'
            IconButton(
              icon: Icon(
                _userData?['profile'] == 'PUBLICO' ? Icons.lock_open : Icons.lock,
                color: Colors.white,
              ),
              onPressed: _toggleProfileVisibility,
              tooltip: _userData?['profile'] == 'PUBLICO' ? 'Tornar Privado' : 'Tornar Público',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _userData == null || _userData!.isEmpty
                  ? Center(child: Text('Nenhum dado de utilizador encontrado ou disponível.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display all attributes from the fetched userData
                          _buildUserInfoRow('Username', _userData!['username']),
                          _buildUserInfoRow('Email', _userData!['email']),
                          _buildUserInfoRow('Nome', _userData!['name']),
                          _buildUserInfoRow('Morada', _userData!['address']),
                          _buildUserInfoRow('Telefone', _userData!['phone']),
                          _buildUserInfoRow('Nacionalidade', _userData!['nationality']),
                          _buildUserInfoRow('País de Residência', _userData!['residenceCountry']),
                          _buildUserInfoRow('NIF', _userData!['nif']),
                          _buildUserInfoRow('Cartão Cidadão', _userData!['cc']),
                          _buildUserInfoRow('Data Emissão CC', _userData!['ccDe']),
                          _buildUserInfoRow('Local Emissão CC', _userData!['ccLe']),
                          _buildUserInfoRow('Validade CC', _userData!['ccV']),
                          _buildUserInfoRow('Data de Nascimento', _userData!['d_nasc']),
                          _buildUserInfoRow('Estado', _userData!['state']),
                          _buildUserInfoRow('Perfil', _userData!['profile']),
                          _buildUserInfoRow('Função', _userData!['role']),
                          _buildUserInfoRow('Tipo de Registo', _userData!['registrationType']),
                          _buildUserInfoRow('Criador', _userData!['creator']),
                          // Password is not displayed

                          SizedBox(height: 30),
                          Center(
                            child: Column(
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    final bool? refresh = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditAccountScreen(
                                          username: widget.username,
                                          jwtToken: widget.jwtToken,
                                          userData: _userData!, // Pass all fetched data to Edit screen
                                        ),
                                      ),
                                    );
                                    if (refresh == true) {
                                      _fetchUserDetails(); // Refresh data if EditAccountScreen returned true
                                    }
                                  },
                                  child: const Text('Editar Conta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _requestAccountDeletion,
                                  child: const Text('Eliminar Conta'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildUserInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Adjust width as needed for labels
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A', // Display value or 'N/A' if null
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}