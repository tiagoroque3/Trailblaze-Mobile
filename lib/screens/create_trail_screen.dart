import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/trail.dart';
import '../services/trail_service.dart';
import '../utils/app_constants.dart';

class CreateTrailScreen extends StatefulWidget {
  final String username;
  final String jwtToken;

  const CreateTrailScreen({
    super.key,
    required this.username,
    required this.jwtToken,
  });

  @override
  State<CreateTrailScreen> createState() => _CreateTrailScreenState();
}

class _CreateTrailScreenState extends State<CreateTrailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  GoogleMapController? _mapController;
  List<TrailPoint> _recordedPoints = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  
  bool _isRecording = false;
  bool _isLoading = false;
  Timer? _recordingTimer;
  TrailVisibility _selectedVisibility = TrailVisibility.PRIVATE;
  
  LatLng? _currentLocation;
  static const LatLng _defaultLocation = LatLng(38.7223, -9.1393); // Lisbon

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, 15),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedPoints.clear();
      _polylines.clear();
      _markers.clear();
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _recordCurrentLocation();
    });

    _showSnackBar('Started recording trail');
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
    });

    _showSnackBar('Stopped recording trail');
  }

  Future<void> _recordCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final point = TrailPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        altitude: position.altitude,
      );

      setState(() {
        _recordedPoints.add(point);
        _updateMapDisplay();
      });
    } catch (e) {
      print('Error recording location: $e');
    }
  }

  void _updateMapDisplay() {
    if (_recordedPoints.isEmpty) return;

    // Update polyline
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('trail'),
          points: _recordedPoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
          color: AppColors.primaryGreen,
          width: 4,
        ),
      };

      // Add markers for start and current position
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(
            _recordedPoints.first.latitude,
            _recordedPoints.first.longitude,
          ),
          infoWindow: const InfoWindow(title: 'Start'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        if (_recordedPoints.length > 1)
          Marker(
            markerId: const MarkerId('current'),
            position: LatLng(
              _recordedPoints.last.latitude,
              _recordedPoints.last.longitude,
            ),
            infoWindow: const InfoWindow(title: 'Current Position'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
      };
    });
  }

  Future<void> _saveTrail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_recordedPoints.isEmpty) {
      _showSnackBar('Please record some trail points first', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await TrailService.createTrail(
        jwtToken: widget.jwtToken,
        name: _nameController.text.trim(),
        visibility: _selectedVisibility,
        points: _recordedPoints,
      );

      _showSnackBar('Trail created successfully!');
      Navigator.of(context).pop();
    } catch (e) {
      _showSnackBar('Error creating trail: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatDistance() {
    if (_recordedPoints.length < 2) return '0.0 km';
    
    double totalDistance = 0.0;
    for (int i = 1; i < _recordedPoints.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        _recordedPoints[i - 1].latitude,
        _recordedPoints[i - 1].longitude,
        _recordedPoints[i].latitude,
        _recordedPoints[i].longitude,
      ) / 1000; // Convert to km
    }
    
    return '${totalDistance.toStringAsFixed(2)} km';
  }

  String _formatDuration() {
    if (_recordedPoints.isEmpty) return '0m';
    if (_recordedPoints.length == 1) return '0m';
    
    final duration = _recordedPoints.last.timestamp
        .difference(_recordedPoints.first.timestamp);
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Trail'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _recordedPoints.isNotEmpty ? _saveTrail : null,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Trail info form
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Trail Name*',
                      hintText: 'Enter trail name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.route),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Trail name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TrailVisibility>(
                    value: _selectedVisibility,
                    decoration: const InputDecoration(
                      labelText: 'Visibility',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.visibility),
                    ),
                    items: TrailVisibility.values.map((visibility) {
                      return DropdownMenuItem(
                        value: visibility,
                        child: Row(
                          children: [
                            Icon(
                              visibility == TrailVisibility.PUBLIC
                                  ? Icons.public
                                  : Icons.lock,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(visibility.name.toLowerCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedVisibility = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Recording controls
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red.shade50 : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('Points', '${_recordedPoints.length}'),
                    _buildStatItem('Distance', _formatDistance()),
                    _buildStatItem('Duration', _formatDuration()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isRecording)
                      ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentLocation != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 15),
                  );
                }
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation ?? _defaultLocation,
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              polylines: _polylines,
              markers: _markers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}