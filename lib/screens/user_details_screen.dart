import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trailblaze_app/screens/login_screen.dart';

class EditAccountScreen extends StatefulWidget {
  final String username;
  final String jwtToken;
  final Map<String, dynamic> userData;

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
  late TextEditingController _fullNameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _nationalityController;
  late TextEditingController _residenceCountryController;
  late TextEditingController _nifController;
  late TextEditingController _ccController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
          const SnackBar(content: Text('Account updated successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        _showErrorDialog(context, 'Failed to update account: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error updating account: $e');
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
          title: const Text('Error'),
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
        title: const Text('Edit Account'),
        backgroundColor: const Color(0xFF4F695B),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildEditableTextField(_fullNameController, 'Full Name', Icons.person),
                  _buildEditableTextField(_addressController, 'Address', Icons.home),
                  _buildEditableTextField(_phoneController, 'Phone', Icons.phone),
                  _buildEditableTextField(_nationalityController, 'Nationality', Icons.flag),
                  _buildEditableTextField(_residenceCountryController, 'Country of Residence', Icons.public),
                  _buildEditableTextField(_nifController, 'NIF', Icons.credit_card),
                  _buildEditableTextField(_ccController, 'Citizen Card', Icons.credit_card),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

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
  final _storage = const FlutterSecureStorage();

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
          _userData = jsonDecode(response.body);
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
      final response = await http.post(
        toggleProfileUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer ${widget.jwtToken}',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile visibility changed successfully!')),
        );
        _fetchUserDetails();
      } else {
        _showErrorDialog(context, 'Failed to change profile visibility: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error changing profile visibility: $e');
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
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to request the deletion of your account? This action is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });

              final Uri removeRequestUrl = Uri.parse('https://trailblaze-460312.appspot.com/rest/account/remove-request');

              try {
                final response = await http.patch(
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
                    const SnackBar(content: Text('Account deletion request submitted successfully!')),
                  );
                  await _logoutUser();
                } else {
                  _showErrorDialog(context, 'Failed to request deletion: ${response.statusCode} - ${response.body}');
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                _showErrorDialog(context, 'Error requesting deletion: $e');
              }
            },
            child: const Text('Confirm'),
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

    await _storage.delete(key: 'jwtToken');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'userRoles');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
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
    List<String> userRoles = (_userData?['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    bool hasRuRole = userRoles.contains('RU');

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: const Color(0xFF4F695B),
        actions: [
          if (hasRuRole)
            IconButton(
              icon: Icon(
                _userData?['profile'] == 'PUBLIC' ? Icons.lock_open : Icons.lock,
                color: Colors.white,
              ),
              onPressed: _toggleProfileVisibility,
              tooltip: _userData?['profile'] == 'PUBLIC' ? 'Make Private' : 'Make Public',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _userData == null || _userData!.isEmpty
                  ? const Center(child: Text('No user data found or available.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserInfoRow('Username', _userData!['username']),
                          _buildUserInfoRow('Email', _userData!['email']),
                          _buildUserInfoRow('Name', _userData!['name']),
                          _buildUserInfoRow('Address', _userData!['address']),
                          _buildUserInfoRow('Phone', _userData!['phone']),
                          _buildUserInfoRow('Nationality', _userData!['nationality']),
                          _buildUserInfoRow('Country of Residence', _userData!['residenceCountry']),
                          _buildUserInfoRow('NIF', _userData!['nif']),
                          _buildUserInfoRow('Citizen Card', _userData!['cc']),
                          _buildUserInfoRow('Citizen Card Issue Date', _userData!['ccDe']),
                          _buildUserInfoRow('Citizen Card Issue Location', _userData!['ccLe']),
                          _buildUserInfoRow('Citizen Card Expiry', _userData!['ccV']),
                          _buildUserInfoRow('Date of Birth', _userData!['d_nasc']),
                          _buildUserInfoRow('State', _userData!['state']),
                          _buildUserInfoRow('Profile', _userData!['profile']),
                          _buildUserInfoRow('Roles', userRoles.isNotEmpty ? userRoles.join(', ') : 'No roles assigned'),
                          _buildUserInfoRow('Registration Type', _userData!['registrationType']),
                          _buildUserInfoRow('Creator', _userData!['creator']),

                          const SizedBox(height: 30),
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
                                          userData: _userData!,
                                        ),
                                      ),
                                    );
                                    if (refresh == true) {
                                      _fetchUserDetails();
                                    }
                                  },
                                  child: const Text('Edit Account'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F695B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _requestAccountDeletion,
                                  child: const Text('Delete Account'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
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
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}