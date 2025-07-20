import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';
import 'package:trailblaze_app/utils/map_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PoLiveTrackingMapScreen extends StatefulWidget {
  final ParcelOperationExecution parcelOperation;
  final String jwtToken;
  final String assignedWorkSheetId;

  const PoLiveTrackingMapScreen({
    super.key,
    required this.parcelOperation,
    required this.jwtToken,
    required this.assignedWorkSheetId,
  });

  @override
  State<PoLiveTrackingMapScreen> createState() =>
      _PoLiveTrackingMapScreenState();
}

class _PoLiveTrackingMapScreenState extends State<PoLiveTrackingMapScreen> {
  GoogleMapController? _mapController;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  bool _isInsideParcel = false;
  String _statusMessage = 'Initializing...';
  StreamSubscription<Position>? _positionStreamSubscription;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBatteryWarning());
    _initializeNotifications();
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'parcel_exit_channel',
          'Parcel Exit',
          channelDescription: 'Notifications for when you exit a parcel area',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> _initializeLocationTracking() async {
    // Check location permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setStatus('Location services are disabled', isError: true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setStatus('Location permissions denied', isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setStatus('Location permissions permanently denied', isError: true);
      return;
    }

    // Start location stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!mounted) return;
            final currentLatLng = LatLng(position.latitude, position.longitude);
            _updateUserMarker(currentLatLng);
            _checkIfInsideParcel(currentLatLng);
          },
        );
  }

  Future<void> _showBatteryWarning() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Battery Usage Warning'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Live location tracking is active.'),
                SizedBox(height: 8),
                Text('This may consume more battery than usual.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeMapAndTracking();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeMapAndTracking() async {
    setState(() {
      _statusMessage = 'Loading parcel boundary...';
    });
    await _fetchParcelGeometry();
  }

  Future<void> _fetchParcelGeometry() async {
    try {
      final String parcelId = widget.parcelOperation.parcelId.toString();

      final geometry = await ExecutionService.fetchParcelGeometry(
        jwtToken: widget.jwtToken,
        worksheetId: widget.assignedWorkSheetId,
        parcelId: parcelId,
      );

      if (mounted && geometry.isNotEmpty) {
        setState(() {
          final parcelPolygon = Polygon(
            polygonId: PolygonId(widget.parcelOperation.parcelId),
            points: geometry,
            strokeColor: AppColors.primaryGreen,
            strokeWidth: 2,
            fillColor: AppColors.primaryGreen.withOpacity(0.2),
          );
          _polygons.add(parcelPolygon);
        });
        _centerOnParcel();
      } else if (mounted) {
        _showSnackBar('Could not load parcel boundary.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to load parcel boundary: $e', isError: true);
    }
  }

  void _updateUserMarker(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'userLocation');
      _markers.add(
        Marker(
          markerId: const MarkerId('userLocation'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    });
  }

  void _checkIfInsideParcel(LatLng position) {
    if (_polygons.isNotEmpty) {
      final polygonPoints = _polygons.first.points;
      final isInside = MapUtils.isPointInPolygon(position, polygonPoints);

      if (_isInsideParcel && !isInside) {
        // User just exited the parcel
        _showNotification(
          'Parcel Exit Warning',
          'You have left the designated parcel area.',
        );
      }

      _setStatus(
        isInside
            ? 'You are inside the parcel.'
            : 'WARNING: You are not inside the correct parcel',
        isError: !isInside,
      );
    }
  }

  void _centerOnParcel() {
    if (_polygons.isEmpty || _mapController == null) {
      _showSnackBar('Parcel boundary not loaded yet.');
      return;
    }
    LatLngBounds bounds = MapUtils.boundsFromLatLngList(_polygons.first.points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }

  void _goToMyLocation() {
    final userMarker = _markers.firstWhere(
      (m) => m.markerId.value == 'userLocation',
      orElse: () => const Marker(markerId: MarkerId('')),
    );

    if (userMarker.markerId.value.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(userMarker.position, 16.5),
      );
    } else {
      _showSnackBar('Your location is not available yet.');
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _isInsideParcel = !isError;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Tracking - Parcel ${widget.parcelOperation.parcelId}',
        ),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(38.7223, -9.1393), // Default to Lisbon
              zoom: 14,
            ),
            polygons: _polygons,
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: _isInsideParcel
                  ? Colors.green.withOpacity(0.8)
                  : Colors.red.withOpacity(0.8),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 16,
            child: Column(
              children: [
                FloatingActionButton.extended(
                  onPressed: _goToMyLocation,
                  label: const Text("Me"),
                  icon: const Icon(Icons.person_pin_circle),
                  heroTag: 'myLocationFab',
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  onPressed: _centerOnParcel,
                  label: const Text("Parcel"),
                  icon: const Icon(Icons.fullscreen),
                  heroTag: 'centerParcelFab',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
