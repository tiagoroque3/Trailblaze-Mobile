import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trailblaze_app/screens/login_screen.dart';
import 'package:trailblaze_app/screens/user_details_screen.dart';
import 'package:trailblaze_app/screens/operation_screen.dart';

// Corrected Google Maps import
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Marker? _userLocationMarker;

  @override
  void initState() {
    super.initState();
    _determinePosition(); // Start fetching location when the screen initializes
  }

  // --- Location and Map Methods ---

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      _showSnackBar('Location services are disabled. Please enable them.', isError: true);
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        _showSnackBar('Location permissions are denied.', isError: true);
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      _showSnackBar('Location permissions are permanently denied. Please enable from app settings.', isError: true);
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _userLocationMarker = Marker(
        markerId: const MarkerId('userLocation'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
      );
    });

    // Animate camera to current location if map is already initialized
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation!, 15), // Zoom level 15
    );

    _listenForLocationChanges(); // Start listening for continuous updates
  }

  void _listenForLocationChanges() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _userLocationMarker = Marker(
            markerId: const MarkerId('userLocation'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'Your Location'),
          );
        });
        // You can optionally animate camera to new location if desired
        // _mapController?.animateCamera(
        //   CameraUpdate.newLatLng(_currentLocation!),
        // );
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // If location is already determined, move camera to it
    if (_currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );
    }
  }

  // --- Authentication/Navigation Methods ---

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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
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
              decoration: const BoxDecoration(
                color: Color(0xFF4F695B),
              ),
              child: Text(
                widget.isLoggedIn ? 'Bem-vindo, ${widget.username}' : 'Modo Visitante',
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
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Operation Management (PO)'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                if (widget.isLoggedIn) {
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
            // Add more menu items here
          ],
        ),
      ),
      body: _currentLocation == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Fetching location...'),
                ],
              ),
            )
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 15,
              ),
              myLocationEnabled: true, // Shows the blue dot for current location
              myLocationButtonEnabled: true, // Shows the button to recenter on location
              markers: _userLocationMarker != null ? {_userLocationMarker!} : {},
              // You can add other map features here like polygons, polylines etc.
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentLocation != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 15),
            );
          } else {
            _showSnackBar('Location not yet available or map not loaded.');
          }
        },
        backgroundColor: const Color(0xFF4F695B),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}