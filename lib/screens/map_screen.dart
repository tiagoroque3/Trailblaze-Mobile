import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Represents the screen dedicated to displaying the map.
/// This screen is accessible to all users, regardless of login status.
class MapScreen extends StatefulWidget {
  final String? username;
  final String? jwtToken;

  const MapScreen({
    super.key,
    this.username,
    this.jwtToken,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controller for the Google Map instance.
  GoogleMapController? _mapController;
  // Stores the current location of the user.
  LatLng? _currentLocation;
  // Marker to display the user's current location on the map.
  Marker? _userLocationMarker;
  // State to manage loading indicator during location fetch.
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    // No automatic location fetch on init anymore.
    // User will trigger it via a button.
  }

  /// Determines the current position of the device.
  ///
  /// Checks for location service enablement and permissions. If not enabled or
  /// permissions are denied, it shows appropriate messages to the user.
  /// If successful, it updates `_currentLocation` and `_userLocationMarker`
  /// and moves the map camera to the current location.
  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true; // Show loading indicator
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
      return; // Exit if services are disabled
    }

    // Check for location permissions.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permissions if denied.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied.', isError: true);
        setState(() {
          _isLoadingLocation = false;
        });
        return; // Exit if permissions are denied
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle cases where permissions are permanently denied.
      _showSnackBar('Location permissions are permanently denied. Please enable from app settings.', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
      return; // Exit if permissions are permanently denied
    }

    // Permissions are granted, get the current position.
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _userLocationMarker = Marker(
          markerId: const MarkerId('userLocation'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
        );
        _isLoadingLocation = false; // Hide loading indicator
      });

      // Animate map camera to current location if the map is already initialized.
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15), // Zoom level 15
      );
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  /// Callback when the Google Map is created.
  ///
  /// Stores the controller and moves the camera to the current location if
  /// it's already available (e.g., from a previous manual fetch).
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 15),
      );
    }
  }

  /// Displays a SnackBar message at the bottom of the screen.
  ///
  /// [message] The text content of the SnackBar.
  /// [isError] If true, the SnackBar background will be red, otherwise green.
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        backgroundColor: const Color(0xFF4F695B),
      ),
      body: _currentLocation == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoadingLocation)
                    const CircularProgressIndicator()
                  else
                    const Icon(
                      Icons.map_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                  const SizedBox(height: 20),
                  Text(
                    _isLoadingLocation
                        ? 'Fetching your current location...'
                        : 'Tap the button below to get your current location on the map.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _isLoadingLocation ? null : _determinePosition,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.location_on, color: Colors.white),
                    label: Text(
                      _isLoadingLocation ? 'Getting Location...' : 'Get My Location',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F695B),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _userLocationMarker != null ? {_userLocationMarker!} : {},
              // You can add other map features here like polygons, polylines etc.
            ),
      floatingActionButton: _currentLocation != null && !_isLoadingLocation
          ? FloatingActionButton(
              onPressed: () {
                if (_mapController != null && _currentLocation != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                  );
                } else {
                  _showSnackBar('Current location not available.');
                }
              },
              backgroundColor: const Color(0xFF4F695B),
              child: const Icon(Icons.my_location, color: Colors.white),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
