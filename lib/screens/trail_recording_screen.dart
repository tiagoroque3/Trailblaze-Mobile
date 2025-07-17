import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/trail.dart';
import '../services/trail_service.dart';
import '../utils/app_constants.dart';

class TrailRecordingScreen extends StatefulWidget {
  final String username;
  final String jwtToken;

  const TrailRecordingScreen({
    super.key,
    required this.username,
    required this.jwtToken,
  });

  @override
  State<TrailRecordingScreen> createState() => _TrailRecordingScreenState();
}

class _TrailRecordingScreenState extends State<TrailRecordingScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isLoading = false;
  
  List<TrailPoint> _recordedPoints = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  TrailVisibility _selectedVisibility = TrailVisibility.PRIVATE;
  String? _selectedWorksheetId;
  
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _observationController.dispose();
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions denied', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions permanently denied', isError: true);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (e) {
      _showSnackBar('Error getting location: $e', isError: true);
    }
  }

  void _startRecording() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a trail name', isError: true);
      return;
    }

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _recordedPoints.clear();
      _polylines.clear();
      _markers.clear();
      _elapsedTime = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      if (_isRecording && !_isPaused) {
        _addTrailPoint(position);
      }
    });

    _showSnackBar('Trail recording started');
  }

  void _pauseRecording() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    _showSnackBar(_isPaused ? 'Recording paused' : 'Recording resumed');
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    _positionStream?.cancel();
    _timer?.cancel();

    if (_recordedPoints.isNotEmpty) {
      _showSaveDialog();
    } else {
      _showSnackBar('No points recorded', isError: true);
    }
  }

  void _addTrailPoint(Position position) {
    final point = TrailPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (point.isValid()) {
      setState(() {
        _recordedPoints.add(point);
        _currentPosition = position;
        _updatePolyline();
        _updateMarkers();
      });
    }
  }

  void _updatePolyline() {
    if (_recordedPoints.length < 2) return;

    final polyline = Polyline(
      polylineId: const PolylineId('trail'),
      points: _recordedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      color: AppColors.primaryGreen,
      width: 4,
      patterns: _isPaused ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
    );

    setState(() {
      _polylines = {polyline};
    });
  }

  void _updateMarkers() {
    Set<Marker> markers = {};

    // Start marker
    if (_recordedPoints.isNotEmpty) {
      final start = _recordedPoints.first;
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(start.latitude, start.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );
    }

    // Current position marker
    if (_currentPosition != null && _isRecording) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Current Position'),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Save Trail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trail Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observationController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observations (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TrailVisibility>(
              value: _selectedVisibility,
              decoration: const InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(),
              ),
              items: TrailVisibility.values.map((visibility) {
                return DropdownMenuItem(
                  value: visibility,
                  child: Text(visibility == TrailVisibility.PUBLIC ? 'Public' : 'Private'),
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _discardTrail();
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveTrail();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _discardTrail() {
    setState(() {
      _recordedPoints.clear();
      _polylines.clear();
      _markers.clear();
      _elapsedTime = Duration.zero;
    });
    _showSnackBar('Trail discarded');
  }

  Future<void> _saveTrail() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a trail name', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = CreateTrailRequest(
        name: _nameController.text.trim(),
        worksheetId: _selectedWorksheetId ?? '1', // Default worksheet
        visibility: _selectedVisibility,
        points: _recordedPoints,
      );

      await TrailService.createTrail(
        request: request,
        jwtToken: widget.jwtToken,
      );

      _showSnackBar('Trail saved successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to save trail: $e', isError: true);
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Trail'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (_isRecording)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _pauseRecording,
              tooltip: _isPaused ? 'Resume' : 'Pause',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Recording controls
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
                  child: Column(
                    children: [
                      if (!_isRecording) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Trail Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.route),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Points: ${_recordedPoints.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_isRecording) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Time: ${_formatDuration(_elapsedTime)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (_isPaused) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'PAUSED',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          
                          if (!_isRecording)
                            ElevatedButton.icon(
                              onPressed: _startRecording,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Recording'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _stopRecording,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Map
                Expanded(
                  child: _currentPosition == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryGreen),
                              SizedBox(height: 16),
                              Text('Getting your location...'),
                            ],
                          ),
                        )
                      : GoogleMap(
                          onMapCreated: (controller) => _mapController = controller,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            zoom: 16,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          polylines: _polylines,
                          markers: _markers,
                          mapType: MapType.hybrid,
                        ),
                ),
              ],
            ),
    );
  }
}